import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "components"

ApplicationWindow {
    id: window
    width: 1200
    height: 800
    minimumWidth: 800
    minimumHeight: 600
    visible: true
    title: "TagStore"
    
    // Helper function for translations (depends on updateTrigger for reactivity)
    property int _langTrigger: languageManager.updateTrigger
    function t(text) { _langTrigger; return languageManager.t(text) }
    
    color: themeManager.background
    
    Behavior on color { ColorAnimation { duration: 200 } }
    
    property var selectedTags: []
    property string searchText: ""
    property bool modelsFetching: false
    property var modelsList: libraryConfig.cachedModels
    
    Timer {
        id: searchDebounce
        interval: 300
        onTriggered: {
            libraryModel.searchKeyword = searchText
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        GlobalHeader {
            id: header
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            
            onSearchTextChanged: function(text) {
                searchText = text
                searchDebounce.restart()
            }
            
            onImportClicked: fileDialog.open()
            onIndexClicked: folderDialog.open()
            onSettingsClicked: settingsDialog.open()
        }
        
        TagFilterBar {
            id: tagBar
            Layout.fillWidth: true
            Layout.preferredHeight: selectedTags.length > 0 || tagBar.recommendedTags.length > 0 ? 70 : 36
            
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200 } }
            
            onTagSelectionChanged: function(tagIds) {
                selectedTags = tagIds
                libraryModel.selectedTagIds = tagIds
            }
        }
        
        ResultsGrid {
            id: resultsGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            model: libraryModel
            
            // Note: Single click now selects file, double click opens it
            // fileClicked signal is no longer emitted for regular clicks
            
            onFileContextMenu: function(fileId, filePath, mouseX, mouseY) {
                contextMenu.currentFileId = fileId
                contextMenu.currentFilePath = filePath
                contextMenu.popup()
            }
            
            onTagClicked: function(tagName) {
                // Find tag ID by name and add to filter
                var allTags = databaseManager.getAllTags()
                for (var i = 0; i < allTags.length; i++) {
                    if (allTags[i].name === tagName) {
                        tagBar.addTag(allTags[i].id, allTags[i].name)
                        break
                    }
                }
            }
            
            onBatchAITagRequested: function(fileIds) {
                console.log("Main.qml received batchAITagRequested, fileIds:", JSON.stringify(fileIds))
                batchAITagDialog.fileIds = fileIds
                batchAITagDialog.open()
            }
            
            onBatchManualTagRequested: function(fileIds) {
                console.log("Main.qml received batchManualTagRequested, fileIds:", JSON.stringify(fileIds))
                batchManualTagDialog.fileIds = fileIds
                batchManualTagDialog.open()
            }
        }
    }
    
    FileDialog {
        id: fileDialog
        title: t("Import Files")
        fileMode: FileDialog.OpenFiles
        
        onAccepted: {
            fileIngestor.processDroppedFiles(selectedFiles, 0)
        }
    }
    
    FolderDialog {
        id: folderDialog
        title: t("Index Folder")
        
        onAccepted: {
            console.log("Selected folder:", selectedFolder)
        }
    }
    
    Menu {
        id: contextMenu
        
        property int currentFileId: -1
        property string currentFilePath: ""
        
        MenuItem {
            text: t("Open")
            onTriggered: Qt.openUrlExternally("file:///" + contextMenu.currentFilePath)
        }
        
        MenuItem {
            text: t("Reveal in Explorer")
            onTriggered: {
                var folder = contextMenu.currentFilePath.substring(0, contextMenu.currentFilePath.lastIndexOf('/'))
                Qt.openUrlExternally("file:///" + folder)
            }
        }
        
        MenuSeparator {}
        
        MenuItem {
            text: t("Manage Tags")
            onTriggered: {
                tagDialog.fileId = contextMenu.currentFileId
                tagDialog.open()
            }
        }
        
        MenuItem {
            text: "✨ " + t("AI Tag")
            onTriggered: {
                aiTagSingleFile(contextMenu.currentFileId)
            }
        }
        
        MenuSeparator {}
        
        MenuItem {
            text: t("Delete")
            onTriggered: {
                deleteConfirmDialog.fileId = contextMenu.currentFileId
                deleteConfirmDialog.open()
            }
        }
    }
    
    // Tag management dialog
    Dialog {
        id: tagDialog
        property int fileId: -1
        property var pendingTags: []  // Temporary tag list for editing
        property var originalTags: [] // Original tags for comparison
        
        title: t("Manage Tags")
        modal: true
        anchors.centerIn: parent
        width: 400
        height: 360
        
        onOpened: {
            // Load current tags into temporary list
            if (fileId > 0) {
                var currentTags = databaseManager.getTagsForFile(fileId)
                pendingTags = currentTags.slice()
                originalTags = currentTags.slice()
            } else {
                pendingTags = []
                originalTags = []
            }
            newTagField.text = ""
            newTagField.forceActiveFocus()
        }
        
        function addTag(tagName) {
            var trimmed = tagName.trim()
            if (trimmed === "") return
            // Split by comma
            var tags = trimmed.split(",")
            for (var i = 0; i < tags.length; i++) {
                var t = tags[i].trim()
                if (t !== "" && pendingTags.indexOf(t) === -1) {
                    pendingTags.push(t)
                }
            }
            pendingTags = pendingTags.slice() // Trigger update
        }
        
        function removeTag(tagName) {
            var idx = pendingTags.indexOf(tagName)
            if (idx !== -1) {
                pendingTags.splice(idx, 1)
                pendingTags = pendingTags.slice() // Trigger update
            }
        }
        
        function applyChanges() {
            // Find tags to add (in pending but not in original)
            var toAdd = pendingTags.filter(function(t) { return originalTags.indexOf(t) === -1 })
            // Find tags to remove (in original but not in pending)
            var toRemove = originalTags.filter(function(t) { return pendingTags.indexOf(t) === -1 })
            
            // Apply additions
            if (toAdd.length > 0) {
                databaseManager.addTagsToFile(fileId, toAdd)
            }
            
            // Apply removals
            for (var i = 0; i < toRemove.length; i++) {
                var tagId = databaseManager.getOrCreateTag(toRemove[i])
                databaseManager.removeTagFromFile(fileId, tagId)
            }
        }
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 12
            
            Label {
                text: t("Tags for this file:")
                color: themeManager.textPrimary
                font.weight: Font.Medium
            }
            
            // Input field with add button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                TextField {
                    id: newTagField
                    Layout.fillWidth: true
                    placeholderText: t("Enter tags separated by comma...")
                    color: themeManager.textPrimary
                    placeholderTextColor: themeManager.textMuted
                    
                    background: Rectangle {
                        color: themeManager.background
                        radius: 8
                        border.color: newTagField.activeFocus ? themeManager.primary : themeManager.border
                    }
                    
                    onAccepted: {
                        tagDialog.addTag(text)
                        text = ""
                    }
                }
                
                Rectangle {
                    width: 36
                    height: 36
                    radius: 8
                    color: addTagBtnMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
                    
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    MouseArea {
                        id: addTagBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tagDialog.addTag(newTagField.text)
                            newTagField.text = ""
                        }
                    }
                }
            }
            
            // Tags display area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: themeManager.background
                radius: 8
                border.color: themeManager.border
                
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 10
                    contentWidth: tagsFlow.width
                    contentHeight: tagsFlow.height
                    clip: true
                    
                    Flow {
                        id: tagsFlow
                        width: parent.width
                        spacing: 8
                        
                        Repeater {
                            model: tagDialog.pendingTags
                            
                            Rectangle {
                                height: 30
                                width: tagText.width + closeBtn.width + 20
                                radius: 4
                                color: themeManager.primaryLight
                                border.color: themeManager.primary
                                border.width: 1
                                
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    
                                    Text {
                                        id: tagText
                                        text: modelData
                                        color: themeManager.primary
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Rectangle {
                                        id: closeBtn
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: closeBtnMouse.containsMouse ? themeManager.primary : "transparent"
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: closeBtnMouse.containsMouse ? "white" : themeManager.primary
                                            font.pixelSize: 10
                                        }
                                        
                                        MouseArea {
                                            id: closeBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: tagDialog.removeTag(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Empty state
                Text {
                    anchors.centerIn: parent
                    text: t("No tags yet")
                    color: themeManager.textMuted
                    font.pixelSize: 13
                    visible: tagDialog.pendingTags.length === 0
                }
            }
            
            // Custom footer buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: cancelTagsMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                    border.color: themeManager.border
                    
                    Text {
                        anchors.centerIn: parent
                        text: t("Cancel")
                        color: themeManager.textSecondary
                    }
                    
                    MouseArea {
                        id: cancelTagsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tagDialog.reject()
                    }
                }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: okTagsMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
                    
                    Text {
                        anchors.centerIn: parent
                        text: t("OK")
                        color: "white"
                    }
                    
                    MouseArea {
                        id: okTagsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tagDialog.applyChanges()
                            tagDialog.accept()
                        }
                    }
                }
            }
        }
    }
    
    // Delete confirmation dialog
    Dialog {
        id: deleteConfirmDialog
        property int fileId: -1
        
        title: t("Delete File")
        modal: true
        anchors.centerIn: parent
        width: 400
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 20
            
            Label {
                text: t("Are you sure you want to remove this file from the library?")
                color: themeManager.textPrimary
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: noDeleteMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                    border.color: themeManager.border
                    
                    Text {
                        anchors.centerIn: parent
                        text: t("No")
                        color: themeManager.textSecondary
                    }
                    
                    MouseArea {
                        id: noDeleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: deleteConfirmDialog.reject()
                    }
                }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: yesDeleteMouse.containsMouse ? "#dc2626" : "#ef4444"
                    
                    Text {
                        anchors.centerIn: parent
                        text: t("Yes")
                        color: "white"
                    }
                    
                    MouseArea {
                        id: yesDeleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            databaseManager.removeFile(deleteConfirmDialog.fileId)
                            deleteConfirmDialog.accept()
                        }
                    }
                }
            }
        }
    }
    
    // Settings dialog
    Dialog {
        id: settingsDialog
        
        title: t("Settings")
        modal: true
        anchors.centerIn: parent
        width: 540
        height: 560
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 20
            
            // Appearance Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Label {
                    text: t("Appearance")
                    color: themeManager.textPrimary
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: appearanceContent.height + 24
                    color: themeManager.background
                    radius: 8
                    border.color: themeManager.border
                    
                    ColumnLayout {
                        id: appearanceContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 12
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Label { 
                                text: t("Theme:")
                                color: themeManager.textSecondary
                                Layout.preferredWidth: 80
                            }
                            
                            ComboBox {
                                id: themeCombo
                                Layout.fillWidth: true
                                model: [t("Light"), t("Dark"), t("System")]
                                currentIndex: themeManager.themeMode
                                
                                onActivated: function(index) {
                                    themeManager.setThemeMode(index)
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Label { 
                                text: t("Language:")
                                color: themeManager.textSecondary
                                Layout.preferredWidth: 80
                            }
                            
                            ComboBox {
                                id: languageCombo
                                Layout.fillWidth: true
                                model: [t("System"), "English", "中文"]
                                currentIndex: languageManager.languageMode
                                
                                onActivated: function(index) {
                                    languageManager.setLanguageMode(index)
                                }
                            }
                        }
                    }
                }
            }
            
            // Library Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Label {
                    text: t("Library")
                    color: themeManager.textPrimary
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: libraryContent.height + 24
                    color: themeManager.background
                    radius: 8
                    border.color: themeManager.border
                    
                    RowLayout {
                        id: libraryContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8
                        
                        Label { 
                            text: t("Library Path:")
                            color: themeManager.textSecondary
                        }
                        
                        TextField {
                            id: libraryPathField
                            Layout.fillWidth: true
                            text: libraryConfig.libraryPath
                            color: themeManager.textPrimary
                            
                            background: Rectangle {
                                color: themeManager.surface
                                radius: 6
                                border.color: themeManager.border
                            }
                        }
                        
                        Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                            color: browseMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                            border.color: themeManager.border
                            
                            Text {
                                anchors.centerIn: parent
                                text: "..."
                                color: themeManager.textSecondary
                            }
                            
                            MouseArea {
                                id: browseMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: libraryFolderDialog.open()
                            }
                        }
                    }
                }
            }
            
            // OpenAI API Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Label {
                    text: t("OpenAI API")
                    color: themeManager.textPrimary
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: apiContent.height + 24
                    color: themeManager.background
                    radius: 8
                    border.color: themeManager.border
                    
                    ColumnLayout {
                        id: apiContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 10
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Label { 
                                text: t("Base URL:")
                                color: themeManager.textSecondary
                                Layout.preferredWidth: 80
                            }
                            TextField {
                                id: apiBaseUrlField
                                Layout.fillWidth: true
                                text: libraryConfig.apiBaseUrl
                                placeholderText: "https://api.openai.com/v1"
                                color: themeManager.textPrimary
                                placeholderTextColor: themeManager.textMuted
                                
                                background: Rectangle {
                                    color: themeManager.surface
                                    radius: 6
                                    border.color: apiBaseUrlField.activeFocus ? themeManager.primary : themeManager.border
                                }
                            }
                            
                            // Refresh button to fetch models
                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 8
                                color: refreshModelsMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                                border.color: themeManager.border
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelsFetching ? "⏳" : "🔄"
                                    font.pixelSize: 16
                                }
                                
                                MouseArea {
                                    id: refreshModelsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !modelsFetching
                                    onClicked: {
                                        modelsFetching = true
                                        llmClient.fetchModels(apiBaseUrlField.text, apiKeyField.text)
                                    }
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Label { 
                                text: t("API Key:")
                                color: themeManager.textSecondary
                                Layout.preferredWidth: 80
                            }
                            TextField {
                                id: apiKeyField
                                Layout.fillWidth: true
                                text: libraryConfig.apiKey
                                echoMode: TextInput.Password
                                placeholderText: "sk-..."
                                color: themeManager.textPrimary
                                placeholderTextColor: themeManager.textMuted
                                
                                background: Rectangle {
                                    color: themeManager.surface
                                    radius: 6
                                    border.color: apiKeyField.activeFocus ? themeManager.primary : themeManager.border
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Label { 
                                text: t("Model:")
                                color: themeManager.textSecondary
                                Layout.preferredWidth: 80
                            }
                            
                            ComboBox {
                                id: modelCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                editable: true
                                model: modelsList
                                
                                Component.onCompleted: {
                                    editText = libraryConfig.model
                                }
                                
                                onActivated: function(index) {
                                    editText = modelsList[index]
                                }
                                
                                popup: Popup {
                                    y: modelCombo.height
                                    width: modelCombo.width
                                    implicitHeight: Math.min(contentItem.implicitHeight + 2, 300)
                                    padding: 1
                                    
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: modelCombo.popup.visible ? modelCombo.delegateModel : null
                                        currentIndex: modelCombo.highlightedIndex
                                        
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }
                                    
                                    background: Rectangle {
                                        color: themeManager.surface
                                        border.color: themeManager.border
                                        radius: 4
                                    }
                                }
                                
                                delegate: ItemDelegate {
                                    width: modelCombo.width
                                    
                                    contentItem: Text {
                                        text: modelData
                                        color: themeManager.textPrimary
                                        font: modelCombo.font
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    highlighted: modelCombo.highlightedIndex === index
                                    
                                    background: Rectangle {
                                        color: highlighted ? themeManager.primary : "transparent"
                                        opacity: highlighted ? 0.2 : 1
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            // Custom footer buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: cancelSettingsMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                    border.color: themeManager.border
                    
                    Text {
                        anchors.centerIn: parent
                        text: t("Cancel")
                        color: themeManager.textSecondary
                    }
                    
                    MouseArea {
                        id: cancelSettingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsDialog.reject()
                    }
                }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: okSettingsMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
                    
                    Text {
                        anchors.centerIn: parent
                        text: t("OK")
                        color: "white"
                    }
                    
                    MouseArea {
                        id: okSettingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            libraryConfig.libraryPath = libraryPathField.text
                            // Update both libraryConfig and llmClient
                            llmClient.baseUrl = apiBaseUrlField.text
                            llmClient.apiKey = apiKeyField.text
                            llmClient.model = modelCombo.editText
                            settingsDialog.accept()
                            console.log("Settings saved. LLM configured:", llmClient.isConfigured())
                        }
                    }
                }
            }
        }
        
        FolderDialog {
            id: libraryFolderDialog
            title: t("Select Library Folder")
            onAccepted: {
                libraryPathField.text = selectedFolder.toString().replace("file:///", "")
            }
        }
    }
    
    // Drop area
    DropArea {
        anchors.fill: parent
        
        onEntered: function(drag) {
            drag.accepted = drag.hasUrls
            dropOverlay.visible = true
        }
        
        onExited: dropOverlay.visible = false
        
        onDropped: function(drop) {
            dropOverlay.visible = false
            if (drop.hasUrls) {
                var mode = drop.modifiers & Qt.AltModifier ? 1 : 0
                fileIngestor.processDroppedFiles(drop.urls, mode)
            }
        }
    }
    
    // Drop overlay
    Rectangle {
        id: dropOverlay
        anchors.fill: parent
        color: themeManager.isDark ? "#c0000000" : "#c0ffffff"
        visible: false
        
        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: 200
            radius: 20
            color: themeManager.surface
            border.color: themeManager.primary
            border.width: 3
            
            Column {
                anchors.centerIn: parent
                spacing: 15
                
                Text {
                    text: "📥"
                    font.pixelSize: 48
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: t("Drop files here to import")
                    color: themeManager.textPrimary
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: t("Hold Alt to index without moving")
                    color: themeManager.textMuted
                    font.pixelSize: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
    
    Connections {
        target: fileIngestor
        
        function onConflictDetected(jobId, newFilename, existingPath, hash) {
            conflictDialog.jobId = jobId
            conflictDialog.newFilename = newFilename
            conflictDialog.existingPath = existingPath
            conflictDialog.open()
        }
        
        function onFileAdded(fileId, filename) {
            console.log("File added:", filename)
        }
    }
    
    Connections {
        target: llmClient
        
        function onModelsFetched(models) {
            console.log("QML received models:", models)
            modelsFetching = false
            if (models.length > 0) {
                modelsList = models
                // Persist to settings
                libraryConfig.setCachedModels(models)
            }
        }
        
        function onModelsFetchError(errorMsg) {
            modelsFetching = false
            console.log("Failed to fetch models:", errorMsg)
        }
    }
    
    // Conflict dialog
    Dialog {
        id: conflictDialog
        
        property string jobId: ""
        property string newFilename: ""
        property string existingPath: ""
        
        title: t("Duplicate File Detected")
        modal: true
        anchors.centerIn: parent
        width: 480
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ColumnLayout {
            spacing: 15
            
            Label {
                text: t("A file with the same content already exists:")
                color: themeManager.textPrimary
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: existingPathText.height + 16
                color: themeManager.background
                radius: 6
                
                Label {
                    id: existingPathText
                    anchors.fill: parent
                    anchors.margins: 8
                    text: conflictDialog.existingPath
                    color: themeManager.textMuted
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }
            
            Label {
                text: t("New file: ") + conflictDialog.newFilename
                color: themeManager.textPrimary
            }
            
            Label {
                text: t("What would you like to do?")
                color: themeManager.textSecondary
            }
        }
        
        footer: RowLayout {
            spacing: 10
            
            Item { Layout.fillWidth: true }
            
            // Skip button
            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 36
                radius: 8
                color: skipMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                border.color: themeManager.border
                
                Text {
                    anchors.centerIn: parent
                    text: t("Skip")
                    color: themeManager.textSecondary
                }
                
                MouseArea {
                    id: skipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        fileIngestor.resolveConflict(conflictDialog.jobId, 0)
                        conflictDialog.close()
                    }
                }
            }
            
            // Copy button
            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 36
                radius: 8
                color: copyMouse.containsMouse ? themeManager.surfaceHover : "transparent"
                border.color: themeManager.primary
                border.width: 1.5
                
                Text {
                    anchors.centerIn: parent
                    text: t("Import as Copy")
                    color: themeManager.primary
                    font.pixelSize: 13
                }
                
                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        fileIngestor.resolveConflict(conflictDialog.jobId, 1)
                        conflictDialog.close()
                    }
                }
            }
            
            // Alias button
            Rectangle {
                Layout.preferredWidth: 110
                Layout.preferredHeight: 36
                radius: 8
                color: aliasMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
                
                Text {
                    anchors.centerIn: parent
                    text: t("Add as Alias")
                    color: "white"
                    font.pixelSize: 13
                }
                
                MouseArea {
                    id: aliasMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        fileIngestor.resolveConflict(conflictDialog.jobId, 2)
                        conflictDialog.close()
                    }
                }
            }
        }
    }
    
    DropBalloon {
        id: dropBalloon
    }
    
    // Batch AI Tag dialog
    Dialog {
        id: batchAITagDialog
        property var fileIds: []
        
        title: "✨ " + t("AI Tag") + " (" + fileIds.length + t(" files") + ")"
        modal: true
        anchors.centerIn: parent
        width: 400
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 16
            
            Text {
                text: t("AI will analyze and generate tags for selected files.")
                color: themeManager.textSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            
            Text {
                id: aiTagProgressText
                text: ""
                color: themeManager.textMuted
                visible: text.length > 0
            }
            
            ProgressBar {
                id: aiTagProgress
                Layout.fillWidth: true
                visible: value > 0
                value: 0
            }
        }
        
        footer: RowLayout {
            spacing: 10
            
            Item { Layout.fillWidth: true }
            
            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 36
                radius: 8
                color: cancelAIMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                border.color: themeManager.border
                
                Text {
                    anchors.centerIn: parent
                    text: t("Cancel")
                    color: themeManager.textSecondary
                }
                
                MouseArea {
                    id: cancelAIMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batchAITagDialog.close()
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                radius: 8
                color: startAIMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
                
                Text {
                    anchors.centerIn: parent
                    text: t("Start")
                    color: "white"
                }
                
                MouseArea {
                    id: startAIMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        startBatchAITag(batchAITagDialog.fileIds)
                    }
                }
            }
        }
    }
    
    // Batch Manual Tag dialog
    Dialog {
        id: batchManualTagDialog
        property var fileIds: []
        
        title: "🏷️ " + t("Manual Tag") + " (" + fileIds.length + t(" files") + ")"
        modal: true
        anchors.centerIn: parent
        width: 400
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 16
            
            Text {
                text: t("Add tags to all selected files:")
                color: themeManager.textSecondary
            }
            
            TextField {
                id: batchTagField
                Layout.fillWidth: true
                placeholderText: t("Enter tags separated by comma...")
                color: themeManager.textPrimary
                placeholderTextColor: themeManager.textMuted
                
                background: Rectangle {
                    color: themeManager.background
                    radius: 6
                    border.color: batchTagField.activeFocus ? themeManager.primary : themeManager.border
                }
            }
            
            Text {
                text: t("Existing tags from all files:")
                color: themeManager.textMuted
                font.pixelSize: 12
            }
            
            Flow {
                Layout.fillWidth: true
                spacing: 6
                
                Repeater {
                    model: databaseManager ? databaseManager.getAllTags() : []
                    
                    Rectangle {
                        width: batchSuggestText.width + 12
                        height: 24
                        radius: 4
                        color: batchSuggestMouse.containsMouse ? themeManager.primaryLight : themeManager.surface
                        border.color: themeManager.border
                        
                        Text {
                            id: batchSuggestText
                            anchors.centerIn: parent
                            text: modelData.name
                            color: themeManager.textSecondary
                            font.pixelSize: 11
                        }
                        
                        MouseArea {
                            id: batchSuggestMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var current = batchTagField.text
                                if (current.length > 0 && !current.endsWith(",")) {
                                    current += ", "
                                }
                                batchTagField.text = current + modelData.name
                            }
                        }
                    }
                }
            }
        }
        
        footer: RowLayout {
            spacing: 10
            
            Item { Layout.fillWidth: true }
            
            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 36
                radius: 8
                color: cancelManualMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                border.color: themeManager.border
                
                Text {
                    anchors.centerIn: parent
                    text: t("Cancel")
                    color: themeManager.textSecondary
                }
                
                MouseArea {
                    id: cancelManualMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batchManualTagDialog.close()
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 36
                radius: 8
                color: applyTagsMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
                
                Text {
                    anchors.centerIn: parent
                    text: t("Apply")
                    color: "white"
                }
                
                MouseArea {
                    id: applyTagsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        applyBatchTags(batchManualTagDialog.fileIds, batchTagField.text)
                        batchManualTagDialog.close()
                    }
                }
            }
        }
    }
    
    // AI tagging functions
    function aiTagSingleFile(fileId) {
        // Push to AI processing queue
        databaseManager.pushToQueue(fileId)
        console.log("Added file to AI tag queue:", fileId)
    }
    
    function startBatchAITag(fileIds) {
        aiTagProgress.value = 0
        aiTagProgressText.text = t("Processing...") + " 0/" + fileIds.length
        
        for (var i = 0; i < fileIds.length; i++) {
            databaseManager.pushToQueue(fileIds[i])
        }
        
        console.log("Added", fileIds.length, "files to AI tag queue")
        batchAITagDialog.close()
        resultsGrid.clearSelection()
    }
    
    function applyBatchTags(fileIds, tagsText) {
        var tags = tagsText.split(",").map(function(t) { return t.trim() }).filter(function(t) { return t.length > 0 })
        
        for (var i = 0; i < fileIds.length; i++) {
            databaseManager.addTagsToFile(fileIds[i], tags)
        }
        
        console.log("Applied tags", tags, "to", fileIds.length, "files")
        batchTagField.text = ""
        resultsGrid.clearSelection()
    }
}
