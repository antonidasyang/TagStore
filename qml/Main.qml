import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.platform as Platform
import "components"

ApplicationWindow {
    id: window
    width: libraryConfig.windowWidth
    height: libraryConfig.windowHeight
    x: libraryConfig.windowX !== -1 ? libraryConfig.windowX : (Screen.width - width) / 2
    y: libraryConfig.windowY !== -1 ? libraryConfig.windowY : (Screen.height - height) / 2
    
    minimumWidth: 800
    minimumHeight: 600
    visible: false
    title: t("Tag Store") + " v" + Qt.application.version
    
    Component.onCompleted: {
        if (!libraryConfig.startMinimized) {
            window.visibility = libraryConfig.windowMaximized ? Window.Maximized : Window.Windowed
            window.visible = true
        }
    }
    
    property bool forceQuit: false
    property bool isQuitting: false
    
    onClosing: function(close) {
        if (isQuitting) {
            if (llmProcessor.isBusy && !forceQuit) {
                close.accepted = false
                quitWaitDialog.open()
            } else {
                // Save state
                libraryConfig.windowMaximized = (window.visibility === Window.Maximized)
                if (window.visibility === Window.Windowed) {
                    libraryConfig.windowWidth = window.width
                    libraryConfig.windowHeight = window.height
                    libraryConfig.windowX = window.x
                    libraryConfig.windowY = window.y
                }
                // Accepted by default
            }
        } else {
            // Minimize to tray
            close.accepted = false
            window.hide()
            dropBalloon.show()
        }
    }
    
    onVisibilityChanged: {
        if (visibility === Window.Minimized) {
            window.hide()
            dropBalloon.show()
        }
    }
    
    Platform.SystemTrayIcon {
        visible: true
        icon.source: "qrc:/icons/icon.png"
        tooltip: t("Tag Store")
        
        onActivated: function(reason) {
            if (reason === Platform.SystemTrayIcon.Trigger) {
                window.show()
                window.raise()
                window.requestActivate()
            }
        }
        
        menu: Platform.Menu {
            Platform.MenuItem {
                text: t("Show Main Window")
                onTriggered: {
                    window.show()
                    window.raise()
                    window.requestActivate()
                }
            }
            
            Platform.MenuItem {
                text: t("Exit")
                onTriggered: {
                    window.isQuitting = true
                    Qt.quit()
                }
            }
        }
    }
    
    // Helper function for translations (depends on updateTrigger for reactivity)
    property int _langTrigger: languageManager.updateTrigger
    function t(text) { _langTrigger; return languageManager.t(text) }
    
    color: themeManager.background
    
    Behavior on color { ColorAnimation { duration: 200 } }
    
    // Track if any modal dialog is open to manage Esc behavior
    property bool _anyDialogVisible: settingsDialog.visible || 
                                     batchAITagDialog.visible || 
                                     batchManualTagDialog.visible || 
                                     deleteConfirmDialog.visible || 
                                     conflictDialog.visible || 
                                     folderImportDialog.visible ||
                                     tagManagerDialog.visible
    
    // Intercept Esc to prevent Main Window from hiding/closing, unless a dialog is handling it
    Shortcut {
        sequence: "Esc"
        enabled: !_anyDialogVisible
        context: Qt.WindowShortcut
        onActivated: resultsGrid.clearSelection()
    }
    
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
            onTagsClicked: tagManagerDialog.open()
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
            
            onFileContextMenu: function(fileId, filePath, isReferenced, mouseX, mouseY) {
                contextMenu.currentFileId = fileId
                contextMenu.currentFilePath = filePath
                contextMenu.currentIsReferenced = isReferenced
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
        modality: Qt.WindowModal
        
        onAccepted: {
            fileIngestor.processDroppedFiles(selectedFiles, 0)
        }
    }
    
    FolderDialog {
        id: folderDialog
        title: t("Index Folder")
        modality: Qt.WindowModal
        
        onAccepted: {
            console.log("Selected folder:", selectedFolder)
        }
    }
    
    Menu {
        id: contextMenu
        
        property int currentFileId: -1
        property string currentFilePath: ""
        property bool currentIsReferenced: false
        
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
                batchManualTagDialog.fileIds = resultsGrid.selectedFileIds
                batchManualTagDialog.open()
            }
        }
        
        MenuItem {
            text: "✨ " + t("AI Tag")
            onTriggered: {
                startBatchAITag(resultsGrid.selectedFileIds)
            }
        }
        
        MenuSeparator {}
        
        MenuItem {
            text: t("Remove")
            onTriggered: {
                deleteConfirmDialog.fileIds = resultsGrid.selectedFileIds
                if (resultsGrid.selectedFileIds.length === 1) {
                    deleteConfirmDialog.isReferenced = contextMenu.currentIsReferenced
                } else {
                    deleteConfirmDialog.isReferenced = false
                }
                deleteConfirmDialog.open()
            }
        }
    }
    
    // Delete confirmation dialog
    Dialog {
        id: deleteConfirmDialog
        property var fileIds: []
        property bool isReferenced: false
        
        modal: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent
        width: 400
        padding: 24
        bottomPadding: 24
        
        Shortcut {
            sequence: "Esc"
            enabled: deleteConfirmDialog.visible
            onActivated: deleteConfirmDialog.close()
        }
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 20
            
            Text {
                text: deleteConfirmDialog.fileIds.length > 1 ? t("Delete Files") : t("Delete File")
                color: themeManager.textPrimary
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            
            Label {
                text: {
                    if (deleteConfirmDialog.fileIds.length === 1) {
                        return deleteConfirmDialog.isReferenced ? 
                            t("Are you sure you want to remove this reference from the library?") : 
                            t("Are you sure you want to remove this file from the library?")
                    } else {
                        return t("Are you sure you want to remove these files from the library?")
                    }
                }
                color: themeManager.textPrimary
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: !deleteConfirmDialog.isReferenced
                
                ButtonGroup {
                    id: deleteOptionGroup
                }
                
                RadioButton {
                    id: restoreRadio
                    text: t("Restore file to original location")
                    checked: true
                    ButtonGroup.group: deleteOptionGroup
                }
                
                RadioButton {
                    id: deleteRadio
                    text: t("Delete")
                    ButtonGroup.group: deleteOptionGroup
                }
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
                            for (var i = 0; i < deleteConfirmDialog.fileIds.length; i++) {
                                var fid = deleteConfirmDialog.fileIds[i]
                                if (deleteConfirmDialog.isReferenced) {
                                    databaseManager.removeFile(fid)
                                } else if (restoreRadio.checked) {
                                    databaseManager.restoreFile(fid)
                                } else {
                                    databaseManager.removeFile(fid)
                                }
                            }
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
        
        modal: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent
        width: 540
        padding: 24
        bottomPadding: 24
        
        Shortcut {
            sequence: "Esc"
            enabled: settingsDialog.visible
            onActivated: settingsDialog.close()
        }
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 20
            
            Text {
                text: t("Settings")
                color: themeManager.textPrimary
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            
            // General Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Label {
                    text: t("General")
                    color: themeManager.textPrimary
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: generalContent.height + 24
                    color: themeManager.background
                    radius: 8
                    border.color: themeManager.border
                    
                    ColumnLayout {
                        id: generalContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 12
                        
                        CheckBox {
                            id: startMinCheck
                            text: t("Start Minimized")
                            checked: libraryConfig.startMinimized
                        }
                        
                        CheckBox {
                            id: startWinCheck
                            text: t("Start with Windows")
                            checked: libraryConfig.startWithWindows
                        }
                    }
                }
            }
            
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
                                
                                onModelChanged: currentIndex = themeManager.themeMode
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
                                model: [t("System"), t("English"), t("Chinese")]
                                currentIndex: languageManager.languageMode
                                
                                onActivated: function(index) {
                                    languageManager.setLanguageMode(index)
                                }
                                
                                onModelChanged: currentIndex = languageManager.languageMode
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
            
            // Import Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Label {
                    text: t("Import Options")
                    color: themeManager.textPrimary
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: importContent.height + 24
                    color: themeManager.background
                    radius: 8
                    border.color: themeManager.border
                    
                    ColumnLayout {
                        id: importContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 12
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Label { 
                                text: t("Default Drop Action:")
                                color: themeManager.textSecondary
                                Layout.preferredWidth: 120
                            }
                            
                            ComboBox {
                                id: importActionCombo
                                Layout.fillWidth: true
                                model: [t("Move to Library"), t("Link to Original")]
                                currentIndex: libraryConfig.defaultImportMode
                                
                                onActivated: function(index) {
                                    libraryConfig.setDefaultImportMode(index)
                                }
                                
                                onModelChanged: currentIndex = libraryConfig.defaultImportMode
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
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            CheckBox {
                                id: autoTagCheck
                                text: t("Auto Tag with AI")
                                checked: libraryConfig.autoAiTag
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
                            libraryConfig.autoAiTag = autoTagCheck.checked
                            libraryConfig.startMinimized = startMinCheck.checked
                            libraryConfig.startWithWindows = startWinCheck.checked
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
        property int lastButtons: Qt.NoButton
        
        onEntered: function(drag) {
            drag.accepted = drag.hasUrls
            dropOverlay.visible = true
            var btns = fileIngestor.mouseButtons()
            if (btns !== 0) lastButtons = btns
            console.log("Drag Entered. App Buttons:", btns)
        }
        
        onPositionChanged: function(drag) {
            var btns = fileIngestor.mouseButtons()
            if (btns !== 0) lastButtons = btns
        }
        
        onExited: dropOverlay.visible = false
        
        onDropped: function(drop) {
            dropOverlay.visible = false
            console.log("Dropped. Last Buttons:", lastButtons, "Proposed Action:", drop.proposedAction)
            
            if (drop.hasUrls) {
                // Check for Right Button (using cached state) OR Ambiguous action (typical for right-drag on Windows)
                var isRightButton = (lastButtons & Qt.RightButton)
                var isAmbiguous = (drop.proposedAction & Qt.MoveAction) && (drop.proposedAction & Qt.CopyAction)
                
                if (isRightButton || isAmbiguous) {
                    console.log("Right Click Drop detected -> Show Menu")
                    dropMenu.droppedUrls = drop.urls
                    dropMenu.popup()
                } else {
                    console.log("Left Click Drop detected -> Default Action")
                    // Left Button - Use default or modifier
                    var mode = libraryConfig.defaultImportMode
                    if (drop.modifiers & Qt.AltModifier) mode = 1 // Alt forces Link
                    fileIngestor.processDroppedFiles(drop.urls, mode)
                }
            }
            // Reset for next drag
            lastButtons = Qt.NoButton
        }
    }
    
    Menu {
        id: dropMenu
        property var droppedUrls: []
        
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        MenuItem {
            text: t("Move to Library")
            onTriggered: fileIngestor.processDroppedFiles(dropMenu.droppedUrls, 0)
        }
        MenuItem {
            text: t("Link to Original")
            onTriggered: fileIngestor.processDroppedFiles(dropMenu.droppedUrls, 1)
        }
        MenuSeparator {}
        MenuItem {
            text: t("Cancel")
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
            if (window.visible) {
                conflictDialog.jobId = jobId
                conflictDialog.newFilename = newFilename
                conflictDialog.existingPath = existingPath
                conflictDialog.open()
            } else {
                conflictWindow.jobId = jobId
                conflictWindow.newFilename = newFilename
                conflictWindow.existingPath = existingPath
                conflictWindow.open()
            }
        }
        
        function onAskFolderHandling(urls, mode) {
            if (window.visible) {
                folderImportDialog.urls = urls
                folderImportDialog.mode = mode
                folderImportDialog.open()
            } else {
                folderImportWindow.urls = urls
                folderImportWindow.mode = mode
                folderImportWindow.open()
            }
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
        
        modal: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent
        width: 480
        padding: 24
        bottomPadding: 24
        
        Shortcut {
            sequence: "Esc"
            enabled: conflictDialog.visible
            onActivated: conflictDialog.close()
        }
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ConflictContent {
            anchors.fill: parent
            newFilename: conflictDialog.newFilename
            existingPath: conflictDialog.existingPath
            
            onResolve: function(resolution) {
                fileIngestor.resolveConflict(conflictDialog.jobId, resolution)
                conflictDialog.close()
            }
        }
    }
    
    DropBalloon {
        id: dropBalloon
        transientParent: null
        visible: true
        
        onRequestShowWindow: {
            window.show()
            window.raise()
            window.requestActivate()
        }
        
        onRequestExit: {
            window.isQuitting = true
            Qt.quit()
        }
    }
    
    // Batch AI Tag dialog
    Dialog {
        id: batchAITagDialog
        property var fileIds: []
        
        modal: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent
        width: 400
        padding: 24
        bottomPadding: 24
        
        Shortcut {
            sequence: "Esc"
            enabled: batchAITagDialog.visible
            onActivated: batchAITagDialog.close()
        }
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 16
            
            Text {
                text: "✨ " + t("AI Tag") + " (" + batchAITagDialog.fileIds.length + t(" files") + ")"
                color: themeManager.textPrimary
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            
            Text {
                text: t("AI will analyze and generate tags for selected files.")
                color: themeManager.textSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font.pixelSize: 13
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
        
        footer: Item {
            implicitHeight: 60
            width: parent.width
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.bottomMargin: 12
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
    }
    
    // Batch Manual Tag dialog
    Dialog {
        id: batchManualTagDialog
        property var fileIds: []
        property var currentTags: [] // For single file management
        
        modal: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent
        width: 400
        padding: 24
        bottomPadding: 24
        
        Shortcut {
            sequence: "Esc"
            enabled: batchManualTagDialog.visible
            onActivated: batchManualTagDialog.close()
        }
        
        onOpened: {
            if (fileIds.length === 1) {
                currentTags = databaseManager.getTagsForFile(fileIds[0])
            } else {
                currentTags = []
            }
            batchTagField.text = ""
            batchTagField.forceActiveFocus()
        }
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 16
            
            Text {
                text: batchManualTagDialog.fileIds.length === 1 ? t("Manage Tags") : "🏷️ " + t("Manual Tag") + " (" + batchManualTagDialog.fileIds.length + t(" files") + ")"
                color: themeManager.textPrimary
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            
            // Single file current tags
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: batchManualTagDialog.fileIds.length === 1
                
                Text {
                    text: t("Current Tags") + ":"
                    color: themeManager.textSecondary
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    
                    Repeater {
                        model: batchManualTagDialog.currentTags
                        
                        Rectangle {
                            height: 24
                            width: currentTagText.width + 26
                            radius: 4
                            color: themeManager.primaryLight
                            border.color: themeManager.primary
                            border.width: 0.5
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                
                                Text {
                                    id: currentTagText
                                    text: modelData
                                    color: themeManager.primary
                                    font.pixelSize: 11
                                }
                                
                                MouseArea {
                                    width: 14
                                    height: 14
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: themeManager.primary
                                        font.pixelSize: 10
                                    }
                                    
                                    onClicked: {
                                        var tagId = databaseManager.getOrCreateTag(modelData)
                                        databaseManager.removeTagFromFile(batchManualTagDialog.fileIds[0], tagId)
                                        batchManualTagDialog.currentTags = databaseManager.getTagsForFile(batchManualTagDialog.fileIds[0])
                                    }
                                }
                            }
                        }
                    }
                    
                    Text {
                        text: t("No tags")
                        color: themeManager.textMuted
                        font.pixelSize: 11
                        font.italic: true
                        visible: batchManualTagDialog.currentTags.length === 0
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: themeManager.border
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }
            }
            
            Text {
                text: batchManualTagDialog.fileIds.length === 1 ? t("Add New Tags") + ":" : t("Add tags to all selected files") + ":"
                color: themeManager.textSecondary
                font.pixelSize: 12
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
                
                onAccepted: {
                    applyBatchTags(batchManualTagDialog.fileIds, batchTagField.text)
                    batchTagField.text = ""
                    if (batchManualTagDialog.fileIds.length === 1) {
                        batchManualTagDialog.currentTags = databaseManager.getTagsForFile(batchManualTagDialog.fileIds[0])
                    }
                }
            }
            
            Text {
                text: t("Existing tags from all files") + ":"
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
        
        footer: Item {
            implicitHeight: 60
            width: parent.width
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.bottomMargin: 12
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
                        text: t("Close")
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
                            batchTagField.text = ""
                            if (batchManualTagDialog.fileIds.length === 1) {
                                batchManualTagDialog.currentTags = databaseManager.getTagsForFile(batchManualTagDialog.fileIds[0])
                            }
                        }
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
    
    TagManagerDialog {
        id: tagManagerDialog
    }
    
    // Folder Import Dialog
    Dialog {
        id: folderImportDialog
        property var urls: []
        property int mode: 0
        
        modal: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent
        width: 450
        padding: 24
        bottomPadding: 24
        
        Shortcut {
            sequence: "Esc"
            enabled: folderImportDialog.visible
            onActivated: folderImportDialog.close()
        }
        
        background: Rectangle {
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
        }
        
        FolderImportContent {
            anchors.fill: parent
            
            onCancel: folderImportDialog.close()
            onOk: {
                fileIngestor.processFilesWithFolderOption(
                    folderImportDialog.urls, 
                    folderImportDialog.mode, 
                    recursiveChecked
                )
                folderImportDialog.close()
            }
        }
    }
    
    // Windows for hidden mode
    Window {
        id: folderImportWindow
        property var urls: []
        property int mode: 0
        
        flags: Qt.FramelessWindowHint | Qt.Dialog | Qt.WindowStaysOnTopHint
        modality: Qt.ApplicationModal
        color: "transparent"
        width: 450
        height: folderContentWin.implicitHeight + 80
        x: (Screen.width - width) / 2
        y: (Screen.height - height) / 2
        
        function open() { show(); requestActivate() }
        function close() { hide() }
        
        Shortcut {
            sequence: "Esc"
            context: Qt.WindowShortcut
            enabled: folderImportWindow.visible
            onActivated: folderImportWindow.close()
        }
        
        Rectangle {
            anchors.fill: parent
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
            focus: true
            
            MouseArea {
                anchors.fill: parent
                property point lastMousePos
                onPressed: function(mouse) { lastMousePos = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        var delta = Qt.point(mouse.x - lastMousePos.x, mouse.y - lastMousePos.y)
                        folderImportWindow.x += delta.x
                        folderImportWindow.y += delta.y
                    }
                }
            }
            
            FolderImportContent {
                id: folderContentWin
                anchors.fill: parent
                anchors.margins: 24
                
                onCancel: folderImportWindow.close()
                onOk: {
                    fileIngestor.processFilesWithFolderOption(
                        folderImportWindow.urls,
                        folderImportWindow.mode,
                        recursiveChecked
                    )
                    folderImportWindow.close()
                }
            }
        }
    }
    
    Window {
        id: conflictWindow
        property string jobId: ""
        property string newFilename: ""
        property string existingPath: ""
        
        flags: Qt.FramelessWindowHint | Qt.Dialog | Qt.WindowStaysOnTopHint
        modality: Qt.ApplicationModal
        color: "transparent"
        width: 480
        height: conflictContentWin.implicitHeight + 80
        x: (Screen.width - width) / 2
        y: (Screen.height - height) / 2
        
        function open() { show(); requestActivate() }
        function close() { hide() }
        
        Shortcut {
            sequence: "Esc"
            context: Qt.WindowShortcut
            enabled: conflictWindow.visible
            onActivated: conflictWindow.close()
        }
        
        Rectangle {
            anchors.fill: parent
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
            focus: true
            
            MouseArea {
                anchors.fill: parent
                property point lastMousePos
                onPressed: function(mouse) { lastMousePos = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        var delta = Qt.point(mouse.x - lastMousePos.x, mouse.y - lastMousePos.y)
                        conflictWindow.x += delta.x
                        conflictWindow.y += delta.y
                    }
                }
            }
            
            ConflictContent {
                id: conflictContentWin
                anchors.fill: parent
                anchors.margins: 24
                newFilename: conflictWindow.newFilename
                existingPath: conflictWindow.existingPath
                
                onResolve: function(resolution) {
                    fileIngestor.resolveConflict(conflictWindow.jobId, resolution)
                    conflictWindow.close()
                }
            }
        }
    }
    
    Window {
        id: quitWaitDialog
        
        flags: Qt.FramelessWindowHint | Qt.Dialog | Qt.WindowStaysOnTopHint
        modality: Qt.ApplicationModal
        color: "transparent"
        
        width: 400
        height: waitContent.implicitHeight + 80
        
        x: (Screen.width - width) / 2
        y: (Screen.height - height) / 2
        
        function open() { show(); requestActivate() }
        function close() { hide() }
        
        Shortcut {
            sequence: "Esc"
            context: Qt.WindowShortcut
            enabled: quitWaitDialog.visible
            onActivated: quitWaitDialog.close()
        }
        
        Rectangle {
            anchors.fill: parent
            color: themeManager.surface
            radius: 12
            border.color: themeManager.border
            focus: true
            
            MouseArea {
                anchors.fill: parent
                property point lastMousePos
                onPressed: function(mouse) { lastMousePos = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        var delta = Qt.point(mouse.x - lastMousePos.x, mouse.y - lastMousePos.y)
                        quitWaitDialog.x += delta.x
                        quitWaitDialog.y += delta.y
                    }
                }
            }
            
            Connections {
                target: llmProcessor
                function onIsBusyChanged() {
                    // Check visibility using visible property for Window
                    if (!llmProcessor.isBusy && quitWaitDialog.visible) {
                        quitWaitDialog.close()
                        Qt.quit()
                    }
                }
            }
            
            ColumnLayout {
                id: waitContent
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20
                
                Text {
                    text: t("Waiting for Background Tasks")
                    color: themeManager.textPrimary
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
                
                RowLayout {
                    spacing: 16
                    
                    Item {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        
                        // Background ring
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: 3
                            border.color: themeManager.primary
                            opacity: 0.2
                        }
                        
                        // Spinning arc
                        Item {
                            anchors.fill: parent
                            clip: true
                            Rectangle {
                                width: parent.width
                                height: parent.height
                                radius: width / 2
                                color: "transparent"
                                border.width: 3
                                border.color: themeManager.primary
                                
                                // Mask half of the circle
                                Rectangle {
                                    width: parent.width
                                    height: parent.height / 2
                                    anchors.bottom: parent.bottom
                                    color: themeManager.surface
                                }
                            }
                            
                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: 800
                                loops: Animation.Infinite
                                running: quitWaitDialog.visible // Check visibility
                            }
                        }
                    }
                    
                    Text {
                        text: t("AI tasks are currently running. Please wait...")
                        color: themeManager.textPrimary
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
                
                Text {
                    text: t("The application will close automatically when tasks are finished.")
                    color: themeManager.textSecondary
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                
                // Footer (Buttons)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    spacing: 10
                    
                    Item { Layout.fillWidth: true }
                    
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 36
                        radius: 8
                        color: forceQuitMouse.containsMouse ? "#dc2626" : "#ef4444"
                        
                        Text {
                            anchors.centerIn: parent
                            text: t("Force Quit")
                            color: "white"
                        }
                        
                        MouseArea {
                            id: forceQuitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                forceQuit = true
                                Qt.quit()
                            }
                        }
                    }
                }
            }
        }
    }
}
