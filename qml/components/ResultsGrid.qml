import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    color: themeManager.background
    focus: true  // Enable keyboard focus
    
    // Helper function for translations
    property int _langTrigger: languageManager.updateTrigger
    function t(text) { _langTrigger; return languageManager.t(text) }
    
    property alias model: gridView.model
    property bool isGridView: true
    
    // Selection support
    property var selectedFileIds: []
    property int lastAnchorFileId: -1  // For Shift range selection (use fileId instead of index)
    property int currentFocusFileId: -1  // Current keyboard focus file ID
    property int currentFocusIndex: -1  // Current keyboard focus index
    
    signal fileClicked(int fileId, string filePath)
    signal fileContextMenu(int fileId, string filePath, bool isReferenced, real mouseX, real mouseY)
    signal tagClicked(string tagName)
    signal selectionChanged(var selectedIds)
    signal batchAITagRequested(var fileIds)
    signal batchManualTagRequested(var fileIds)
    
    Behavior on color { ColorAnimation { duration: 200 } }
    
    // Keyboard navigation
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            clearSelection()
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || 
            event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            navigateWithKeys(event.key, event.modifiers & Qt.ShiftModifier)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            // Enter to open file
            if (currentFocusFileId > 0) {
                Qt.openUrlExternally("file:///" + getFilePathById(currentFocusFileId))
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            // Space to toggle selection
            if (currentFocusFileId > 0) {
                toggleItemSelection(currentFocusFileId)
                lastAnchorFileId = currentFocusFileId
            }
            event.accepted = true
        }
    }
    
    // Top toolbar with view toggle and selection controls
    RowLayout {
        id: toolbar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        height: 32
        z: 10
        
        // Selection controls
        RowLayout {
            spacing: 8
            visible: selectedFileIds.length > 0
            
            Text {
                text: t("Selected:") + " " + selectedFileIds.length
                color: themeManager.textSecondary
                font.pixelSize: 12
            }
            
            // Batch actions when files are selected
            Rectangle {
                visible: selectedFileIds.length > 0
                width: aiTagBatchText.width + 16
                height: 26
                radius: 4
                color: aiTagBatchMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
                
                Text {
                    id: aiTagBatchText
                    anchors.centerIn: parent
                    text: "✨ " + t("AI Tag")
                    color: "white"
                    font.pixelSize: 11
                }
                
                MouseArea {
                    id: aiTagBatchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batchAITag()
                }
            }
            
            Rectangle {
                visible: selectedFileIds.length > 0
                width: manualTagBatchText.width + 16
                height: 26
                radius: 4
                color: manualTagBatchMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                border.color: themeManager.border
                
                Text {
                    id: manualTagBatchText
                    anchors.centerIn: parent
                    text: "🏷️ " + t("Manual Tag")
                    color: themeManager.textPrimary
                    font.pixelSize: 11
                }
                
                MouseArea {
                    id: manualTagBatchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batchManualTag()
                }
            }
        }
        
        Item { Layout.fillWidth: true }
        
        // View toggle buttons
        Row {
            spacing: 2
            
            Rectangle {
                width: 26
                height: 26
                radius: 4
                color: isGridView ? themeManager.primary : (gridBtnMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface)
                border.color: themeManager.border
                border.width: isGridView ? 0 : 1
                
                Grid {
                    anchors.centerIn: parent
                    columns: 3
                    rows: 2
                    spacing: 2
                    
                    Repeater {
                        model: 6
                        Rectangle {
                            width: 5
                            height: 5
                            radius: 1
                            color: isGridView ? "white" : themeManager.textSecondary
                        }
                    }
                }
                
                MouseArea {
                    id: gridBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: isGridView = true
                }
            }
            
            Rectangle {
                width: 26
                height: 26
                radius: 4
                color: !isGridView ? themeManager.primary : (listBtnMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface)
                border.color: themeManager.border
                border.width: !isGridView ? 0 : 1
                
                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 12
                            height: 2
                            radius: 1
                            color: !isGridView ? "white" : themeManager.textSecondary
                        }
                    }
                }
                
                MouseArea {
                    id: listBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: isGridView = false
                }
            }
        }
    }
    
    // Empty state
    Column {
        anchors.centerIn: parent
        spacing: 20
        visible: gridView.count === 0
        
        Text {
            text: "📂"
            font.pixelSize: 64
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 0.4
        }
        
        Text {
            text: t("No files in library")
            color: themeManager.textMuted
            font.pixelSize: 18
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Text {
            text: t("Drop files here or click Import to get started")
            color: themeManager.textMuted
            font.pixelSize: 14
            opacity: 0.7
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
    
    // Selection rectangle for drag-select
    Rectangle {
        id: selectionRect
        visible: false
        color: Qt.rgba(themeManager.primary.r, themeManager.primary.g, themeManager.primary.b, 0.1)
        border.color: themeManager.primary
        border.width: 1
        z: 100
    }
    
    // Grid view (Card mode)
    GridView {
        id: gridView
        anchors.fill: parent
        anchors.topMargin: 48
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        
        visible: isGridView
        interactive: false  // Disable drag scrolling, use wheel instead
        
        cellWidth: 160
        cellHeight: 180
        
        clip: true
        
        delegate: FileCard {
            width: gridView.cellWidth - 10
            height: gridView.cellHeight - 10
            
            fileId: model.fileId
            filename: model.filename
            filePath: model.filePath
            isReferenced: model.isReferenced
            isAITagged: model.isAITagged
            isDir: model.isDir
            tags: model.tags
            
            isSelected: root.selectedFileIds.indexOf(model.fileId) !== -1
            isFocused: root.currentFocusFileId === model.fileId
            
            onClicked: function(ctrlKey, shiftKey) {
                var currentFileId = model.fileId
                var currentIndex = index
                
                // Update focus when clicking
                root.currentFocusIndex = currentIndex
                root.currentFocusFileId = currentFileId
                
                if (ctrlKey && !shiftKey) {
                    // Ctrl+click: toggle selection without affecting others
                    var wasSelected = root.selectedFileIds.indexOf(currentFileId) !== -1
                    toggleItemSelection(currentFileId)
                    root.lastAnchorFileId = currentFileId
                    // If deselected, also clear focus
                    if (wasSelected) {
                        root.currentFocusFileId = -1
                        root.currentFocusIndex = -1
                    }
                } else if (shiftKey && !ctrlKey) {
                    // Shift+click: range select from anchor to current
                    if (root.lastAnchorFileId < 0) {
                        // No anchor, use first selected item or current
                        if (root.selectedFileIds.length > 0) {
                            root.lastAnchorFileId = root.selectedFileIds[0]
                        } else {
                            root.lastAnchorFileId = currentFileId
                        }
                    }
                    selectRangeByFileId(root.lastAnchorFileId, currentFileId)
                } else if (ctrlKey && shiftKey) {
                    // Ctrl+Shift+click: add range to selection
                    if (root.lastAnchorFileId < 0) {
                        root.lastAnchorFileId = currentFileId
                    }
                    addRangeToSelectionByFileId(root.lastAnchorFileId, currentFileId)
                } else {
                    // Normal click: select only this item, clear others
                    selectSingleItem(currentFileId)
                    root.lastAnchorFileId = currentFileId
                }
            }
            
            onDoubleClicked: {
                // Double click: open file
                Qt.openUrlExternally("file:///" + model.filePath)
            }
            
            onRightClicked: function(mouseX, mouseY) {
                // Right click: select if not selected, then show context menu
                if (root.selectedFileIds.indexOf(model.fileId) === -1) {
                    selectSingleItem(model.fileId)
                }
                root.fileContextMenu(model.fileId, model.filePath, model.isReferenced, mouseX, mouseY)
            }
            
            onTagClicked: function(tagName) {
                root.tagClicked(tagName)
            }
        }
        
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            
            contentItem: Rectangle {
                implicitWidth: 8
                radius: 4
                color: parent.pressed ? themeManager.textMuted : themeManager.border
            }
            
            background: Rectangle {
                implicitWidth: 8
                color: "transparent"
            }
        }
    }
    
    // List view
    ListView {
        id: listView
        anchors.fill: parent
        anchors.topMargin: 44
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        
        visible: !isGridView
        model: gridView.model
        interactive: false  // Disable drag scrolling, use wheel instead
        
        clip: true
        spacing: 8
        
        delegate: Rectangle {
            id: listItem
            width: listView.width
            height: tagsExpanded ? (64 + expandedTagsFlow.implicitHeight + 8) : 64
            radius: 12
            
            property bool isItemSelected: root.selectedFileIds.indexOf(model.fileId) !== -1
            property bool isItemFocused: root.currentFocusFileId === model.fileId
            property bool tagsExpanded: false
            property var itemTags: model.tags || []
            
            color: isItemSelected ? themeManager.primaryLight : (listItemMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface)
            border.color: {
                if (isItemSelected) return themeManager.primary
                if (isItemFocused) return themeManager.primary
                if (listItemMouse.containsMouse) return themeManager.primary
                return themeManager.border
            }
            border.width: {
                if (isItemSelected || isItemFocused) return 1.5
                if (listItemMouse.containsMouse) return 1.5
                return 1
            }
            
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on height { NumberAnimation { duration: 200 } }
            
            RowLayout {
                id: mainInfoRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 64
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12
                
                // File icon
                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    Layout.alignment: Qt.AlignVCenter
                    radius: 8
                    color: themeManager.background
                    
                    Text {
                        anchors.centerIn: parent
                        text: model.isDir ? "📁" : getFileIcon(model.filename)
                        font.pixelSize: 22
                    }
                }
                
                // File info
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        Text {
                            text: model.filename
                            color: themeManager.textPrimary
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: themeManager.success
                            visible: model.isReferenced
                            
                            Text {
                                anchors.centerIn: parent
                                text: "🔗"
                                font.pixelSize: 9
                            }
                        }
                        
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: themeManager.purple
                            visible: model.isAITagged
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✨"
                                font.pixelSize: 9
                            }
                        }
                    }
                    
                    // Tags row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: !listItem.tagsExpanded
                        
                        Repeater {
                            model: listItem.itemTags.slice(0, 5)
                            
                            Rectangle {
                                width: tagTextCollapsed.width + 12
                                height: 22
                                radius: 4
                                color: tagCollapsedMouse.containsMouse ? themeManager.primary : themeManager.primaryLight
                                
                                Text {
                                    id: tagTextCollapsed
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: tagCollapsedMouse.containsMouse ? "white" : themeManager.primary
                                    font.pixelSize: 11
                                }
                                
                                MouseArea {
                                    id: tagCollapsedMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.tagClicked(modelData)
                                }
                            }
                        }
                        
                        Rectangle {
                            visible: listItem.itemTags.length > 5
                            width: expandText.width + 12
                            height: 22
                            radius: 4
                            color: expandBtnMouse.containsMouse ? themeManager.primary : themeManager.surfaceHover
                            
                            Text {
                                id: expandText
                                anchors.centerIn: parent
                                text: "+" + (listItem.itemTags.length - 5) + " ▼"
                                color: expandBtnMouse.containsMouse ? "white" : themeManager.textMuted
                                font.pixelSize: 11
                            }
                            
                            MouseArea {
                                id: expandBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: listItem.tagsExpanded = true
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                    }
                }
            }
            
            // Expanded tags
            Flow {
                id: expandedTagsFlow
                anchors.top: mainInfoRow.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 62 // 12 + 38 + 12
                anchors.rightMargin: 12
                spacing: 6
                visible: listItem.tagsExpanded
                
                Repeater {
                    model: listItem.tagsExpanded ? listItem.itemTags : []
                    
                    Rectangle {
                        width: tagTextExpanded.width + 12
                        height: 24
                        radius: 4
                        color: tagExpandedMouse.containsMouse ? themeManager.primary : themeManager.primaryLight
                        
                        Text {
                            id: tagTextExpanded
                            anchors.centerIn: parent
                            text: modelData
                            color: tagExpandedMouse.containsMouse ? "white" : themeManager.primary
                            font.pixelSize: 11
                        }
                        
                        MouseArea {
                            id: tagExpandedMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tagClicked(modelData)
                        }
                    }
                }
                
                Rectangle {
                    width: collapseText.width + 12
                    height: 24
                    radius: 4
                    color: collapseBtnMouse.containsMouse ? themeManager.primary : themeManager.surfaceHover
                    
                    Text {
                        id: collapseText
                        anchors.centerIn: parent
                        text: "▲ " + t("Collapse")
                        color: collapseBtnMouse.containsMouse ? "white" : themeManager.textMuted
                        font.pixelSize: 11
                    }
                    
                    MouseArea {
                        id: collapseBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: listItem.tagsExpanded = false
                    }
                }
            }
            
            MouseArea {
                id: listItemMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                propagateComposedEvents: true
                
                onClicked: function(mouse) {
                    var currentFileId = model.fileId
                    var currentIndex = index
                    
                    // Update focus when clicking
                    root.currentFocusIndex = currentIndex
                    root.currentFocusFileId = currentFileId
                    
                    if (mouse.button === Qt.RightButton) {
                        // Right click: select if not selected, then show context menu
                        if (root.selectedFileIds.indexOf(currentFileId) === -1) {
                            selectSingleItem(currentFileId)
                            root.lastAnchorFileId = currentFileId
                        }
                        root.fileContextMenu(currentFileId, model.filePath, mouse.x, mouse.y)
                    } else {
                        // Left click
                        var ctrlKey = (mouse.modifiers & Qt.ControlModifier) !== 0
                        var shiftKey = (mouse.modifiers & Qt.ShiftModifier) !== 0
                        
                        if (ctrlKey && !shiftKey) {
                            // Ctrl+click: toggle selection without affecting others
                            var wasSelected = root.selectedFileIds.indexOf(currentFileId) !== -1
                            toggleItemSelection(currentFileId)
                            root.lastAnchorFileId = currentFileId
                            // If deselected, also clear focus
                            if (wasSelected) {
                                root.currentFocusFileId = -1
                                root.currentFocusIndex = -1
                            }
                        } else if (shiftKey && !ctrlKey) {
                            // Shift+click: range select from anchor to current
                            if (root.lastAnchorFileId < 0) {
                                // No anchor, use first selected item or current
                                if (root.selectedFileIds.length > 0) {
                                    root.lastAnchorFileId = root.selectedFileIds[0]
                                } else {
                                    root.lastAnchorFileId = currentFileId
                                }
                            }
                            selectRangeByFileId(root.lastAnchorFileId, currentFileId)
                        } else if (ctrlKey && shiftKey) {
                            // Ctrl+Shift+click: add range to selection
                            if (root.lastAnchorFileId < 0) {
                                root.lastAnchorFileId = currentFileId
                            }
                            addRangeToSelectionByFileId(root.lastAnchorFileId, currentFileId)
                        } else {
                            // Normal click: select only this item, clear others
                            selectSingleItem(currentFileId)
                            root.lastAnchorFileId = currentFileId
                        }
                    }
                }
                
                onDoubleClicked: {
                    // Double click: open file
                    Qt.openUrlExternally("file:///" + model.filePath)
                }
            }
            
            function getFileIcon(filename) {
                var ext = filename.split('.').pop().toLowerCase()
                switch(ext) {
                    case 'pdf': return '📄'
                    case 'doc': case 'docx': return '📝'
                    case 'xls': case 'xlsx': return '📊'
                    case 'ppt': case 'pptx': return '📽️'
                    case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp': return '🖼️'
                    case 'mp3': case 'wav': case 'flac': return '🎵'
                    case 'mp4': case 'mkv': case 'avi': return '🎬'
                    case 'zip': case 'rar': case '7z': return '📦'
                    case 'txt': case 'md': return '📃'
                    case 'html': case 'css': case 'js': case 'cpp': case 'h': case 'py': return '💻'
                    default: return '📁'
                }
            }
        }
        
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            
            contentItem: Rectangle {
                implicitWidth: 8
                radius: 4
                color: parent.pressed ? themeManager.textMuted : themeManager.border
            }
            
            background: Rectangle {
                implicitWidth: 8
                color: "transparent"
            }
        }
    }
    
    // Drag-select and scroll area - only handles drag, clicks pass through
    MouseArea {
        id: dragSelectArea
        anchors.fill: parent
        anchors.topMargin: 48
        acceptedButtons: Qt.LeftButton
        z: 100  // Ensure it's on top to catch drags
        
        property point startPoint
        property bool isDragging: false
        
        onPressed: function(mouse) {
            // Check if we clicked on an item or empty space
            var contentX = mouse.x
            var contentY = mouse.y
            var item = null

            if (isGridView) {
                item = gridView.contentItem.childAt(contentX, contentY + gridView.contentY)
            } else {
                item = listView.contentItem.childAt(contentX, contentY + listView.contentY)
            }

            if (item) {
                // Clicked on a file card -> pass event through to the item
                mouse.accepted = false
            } else {
                // Clicked on empty space -> accept event to start potential drag
                mouse.accepted = true
                startPoint = Qt.point(mouse.x, mouse.y)
                isDragging = false
                root.forceActiveFocus()
            }
        }
        
        onPositionChanged: function(mouse) {
            if (!pressed) return
            
            var dx = Math.abs(mouse.x - startPoint.x)
            var dy = Math.abs(mouse.y - startPoint.y)
            
            // Start drag select after moving more than 10 pixels
            if (!isDragging && (dx > 10 || dy > 10)) {
                isDragging = true
                selectionRect.visible = true
            }
            
            if (isDragging) {
                var x1 = Math.min(startPoint.x, mouse.x)
                var y1 = Math.min(startPoint.y, mouse.y)
                var x2 = Math.max(startPoint.x, mouse.x)
                var y2 = Math.max(startPoint.y, mouse.y)
                
                selectionRect.x = x1
                selectionRect.y = y1 + 48
                selectionRect.width = x2 - x1
                selectionRect.height = y2 - y1
                
                // Select items within rectangle
                selectItemsInRect(x1, y1, x2, y2)
            }
        }
        
        onReleased: function(mouse) {
            if (!isDragging) {
                if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                    clearSelection()
                    root.currentFocusFileId = -1
                    root.currentFocusIndex = -1
                }
            }
            isDragging = false
            selectionRect.visible = false
        }
        
        onCanceled: {
            isDragging = false
            selectionRect.visible = false
        }
        
        // Handle mouse wheel for scrolling (since interactive is disabled)
        onWheel: function(wheel) {
            var scrollAmount = wheel.angleDelta.y / 2
            if (isGridView) {
                gridView.contentY = Math.max(0, Math.min(gridView.contentY - scrollAmount, 
                    Math.max(0, gridView.contentHeight - gridView.height)))
            } else {
                listView.contentY = Math.max(0, Math.min(listView.contentY - scrollAmount,
                    Math.max(0, listView.contentHeight - listView.height)))
            }
        }
    }
    
    // File count indicator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 16
        
        width: countText.width + 16
        height: 26
        radius: 13
        color: themeManager.surface
        border.color: themeManager.border
        border.width: 1
        
        Text {
            id: countText
            anchors.centerIn: parent
            text: gridView.count + t(" files")
            color: themeManager.textMuted
            font.pixelSize: 11
        }
    }
    
    // Functions
    function selectAll() {
        selectedFileIds = []
        for (var i = 0; i < gridView.count; i++) {
            var item = gridView.model.get ? gridView.model.get(i) : null
            if (item) {
                selectedFileIds.push(item.fileId)
            }
        }
        // Alternative: iterate through model
        if (selectedFileIds.length === 0 && libraryModel) {
            for (var j = 0; j < libraryModel.count; j++) {
                selectedFileIds.push(libraryModel.getFileIdAt(j))
            }
        }
        selectedFileIds = selectedFileIds.slice()
        selectionChanged(selectedFileIds)
    }
    
    function clearSelection() {
        selectedFileIds = []
        selectionChanged([])
    }
    
    function selectSingleItem(fileId) {
        // Select only this item, clear others
        selectedFileIds = [fileId]
        selectionChanged(selectedFileIds)
    }
    
    function toggleItemSelection(fileId) {
        var idx = selectedFileIds.indexOf(fileId)
        if (idx === -1) {
            selectedFileIds.push(fileId)
        } else {
            selectedFileIds.splice(idx, 1)
        }
        selectedFileIds = selectedFileIds.slice()
        selectionChanged(selectedFileIds)
    }
    
    function selectRange(fromIndex, toIndex) {
        // Shift+click: select range, replace current selection (deprecated - use selectRangeByFileId)
        if (fromIndex < 0) fromIndex = toIndex
        
        var start = Math.min(fromIndex, toIndex)
        var end = Math.max(fromIndex, toIndex)
        
        var newSelection = []
        for (var i = start; i <= end; i++) {
            var fileId = libraryModel.getFileIdAt(i)
            if (fileId > 0) {
                newSelection.push(fileId)
            }
        }
        
        selectedFileIds = newSelection.slice()
        selectionChanged(selectedFileIds)
    }
    
    function selectRangeByFileId(fromFileId, toFileId) {
        // Shift+click: select range by fileId, works across view modes
        if (fromFileId < 0) {
            // No anchor, just select the clicked item
            selectSingleItem(toFileId)
            return
        }
        
        // Find indices of both files
        var fromIndex = -1
        var toIndex = -1
        
        for (var i = 0; i < libraryModel.count; i++) {
            var fileId = libraryModel.getFileIdAt(i)
            if (fileId === fromFileId) {
                fromIndex = i
            }
            if (fileId === toFileId) {
                toIndex = i
            }
            if (fromIndex >= 0 && toIndex >= 0) break
        }
        
        if (fromIndex < 0 || toIndex < 0) {
            // One of the files not found, just select the clicked one
            selectSingleItem(toFileId)
            return
        }
        
        var start = Math.min(fromIndex, toIndex)
        var end = Math.max(fromIndex, toIndex)
        
        var newSelection = []
        for (var i = start; i <= end; i++) {
            var fileId = libraryModel.getFileIdAt(i)
            if (fileId > 0) {
                newSelection.push(fileId)
            }
        }
        
        selectedFileIds = newSelection.slice()
        selectionChanged(selectedFileIds)
    }
    
    function addRangeToSelection(fromIndex, toIndex) {
        // Ctrl+Shift+click: add range to existing selection (deprecated - use addRangeToSelectionByFileId)
        if (fromIndex < 0) fromIndex = toIndex
        
        var start = Math.min(fromIndex, toIndex)
        var end = Math.max(fromIndex, toIndex)
        
        for (var i = start; i <= end; i++) {
            var fileId = libraryModel.getFileIdAt(i)
            if (fileId > 0 && selectedFileIds.indexOf(fileId) === -1) {
                selectedFileIds.push(fileId)
            }
        }
        
        selectedFileIds = selectedFileIds.slice()
        selectionChanged(selectedFileIds)
    }
    
    function addRangeToSelectionByFileId(fromFileId, toFileId) {
        // Ctrl+Shift+click: add range to existing selection by fileId
        if (fromFileId < 0) {
            // No anchor, just toggle the clicked item
            toggleItemSelection(toFileId)
            return
        }
        
        // Find indices of both files
        var fromIndex = -1
        var toIndex = -1
        
        for (var i = 0; i < libraryModel.count; i++) {
            var fileId = libraryModel.getFileIdAt(i)
            if (fileId === fromFileId) {
                fromIndex = i
            }
            if (fileId === toFileId) {
                toIndex = i
            }
            if (fromIndex >= 0 && toIndex >= 0) break
        }
        
        if (fromIndex < 0 || toIndex < 0) {
            // One of the files not found, just toggle the clicked one
            toggleItemSelection(toFileId)
            return
        }
        
        var start = Math.min(fromIndex, toIndex)
        var end = Math.max(fromIndex, toIndex)
        
        for (var i = start; i <= end; i++) {
            var fileId = libraryModel.getFileIdAt(i)
            if (fileId > 0 && selectedFileIds.indexOf(fileId) === -1) {
                selectedFileIds.push(fileId)
            }
        }
        
        selectedFileIds = selectedFileIds.slice()
        selectionChanged(selectedFileIds)
    }
    
    function selectItemsInRect(x1, y1, x2, y2) {
        // Calculate which items fall within the selection rectangle
        var newSelection = []
        
        if (isGridView) {
            // Grid view selection
            var cellW = gridView.cellWidth
            var cellH = gridView.cellHeight
            var cols = Math.floor((gridView.width - 32) / cellW)  // Account for margins
            
            for (var i = 0; i < gridView.count; i++) {
                var row = Math.floor(i / cols)
                var col = i % cols
                var itemX = 16 + col * cellW + cellW / 2  // Account for left margin
                var itemY = 48 + row * cellH + cellH / 2 - gridView.contentY  // Account for top margin
                
                // Check if item center is within selection rect
                if (itemX >= x1 && itemX <= x2 && itemY >= y1 && itemY <= y2) {
                    var fileId = libraryModel.getFileIdAt(i)
                    if (fileId > 0) {
                        newSelection.push(fileId)
                    }
                }
            }
        } else {
            // List view selection
            var itemHeight = 56  // List item height
            var leftMargin = 16
            var rightEdge = listView.width - 16
            
            for (var i = 0; i < listView.count; i++) {
                var itemY = 48 + i * (itemHeight + 4) + itemHeight / 2 - listView.contentY  // Account for top margin and spacing
                
                // Check if item center is within selection rect (horizontally full width)
                if (itemY >= y1 && itemY <= y2) {
                    // Check if horizontally overlaps (list items span full width)
                    if (x2 >= leftMargin && x1 <= rightEdge) {
                        var fileId = libraryModel.getFileIdAt(i)
                        if (fileId > 0) {
                            newSelection.push(fileId)
                        }
                    }
                }
            }
        }
        
        selectedFileIds = newSelection.slice()
        selectionChanged(selectedFileIds)
    }
    
    function navigateWithKeys(key, shiftPressed) {
        var newIndex = currentFocusIndex
        
        if (currentFocusIndex < 0) {
            // No current focus, start from first item
            if (libraryModel.count > 0) {
                newIndex = 0
            } else {
                return
            }
        } else {
            // Calculate new index based on key
            if (isGridView) {
                // Grid view navigation
                var cellW = gridView.cellWidth
                var cols = Math.floor((gridView.width - 32) / cellW)
                
                if (key === Qt.Key_Up) {
                    newIndex = Math.max(0, currentFocusIndex - cols)
                } else if (key === Qt.Key_Down) {
                    newIndex = Math.min(libraryModel.count - 1, currentFocusIndex + cols)
                } else if (key === Qt.Key_Left) {
                    newIndex = Math.max(0, currentFocusIndex - 1)
                } else if (key === Qt.Key_Right) {
                    newIndex = Math.min(libraryModel.count - 1, currentFocusIndex + 1)
                }
            } else {
                // List view navigation
                if (key === Qt.Key_Up) {
                    newIndex = Math.max(0, currentFocusIndex - 1)
                } else if (key === Qt.Key_Down) {
                    newIndex = Math.min(libraryModel.count - 1, currentFocusIndex + 1)
                } else if (key === Qt.Key_Left || key === Qt.Key_Right) {
                    // Left/Right don't do anything in list view
                    return
                }
            }
        }
        
        if (newIndex >= 0 && newIndex < libraryModel.count) {
            var newFileId = libraryModel.getFileIdAt(newIndex)
            
            if (shiftPressed) {
                // Shift+arrow: range select from anchor to current
                if (root.lastAnchorFileId < 0) {
                    // No anchor, use first selected item or current focus
                    if (root.selectedFileIds.length > 0) {
                        root.lastAnchorFileId = root.selectedFileIds[0]
                    } else {
                        root.lastAnchorFileId = root.currentFocusFileId > 0 ? root.currentFocusFileId : newFileId
                    }
                }
                // Select range from anchor to new position
                selectRangeByFileId(root.lastAnchorFileId, newFileId)
            } else {
                // Normal arrow: move focus and select only this item
                selectSingleItem(newFileId)
                root.lastAnchorFileId = newFileId
            }
            
            // Update focus
            root.currentFocusIndex = newIndex
            root.currentFocusFileId = newFileId
            
            // Scroll to make item visible
            scrollToIndex(newIndex)
        }
    }
    
    function scrollToIndex(index) {
        if (isGridView) {
            var cellW = gridView.cellWidth
            var cellH = gridView.cellHeight
            var cols = Math.floor((gridView.width - 32) / cellW)
            var row = Math.floor(index / cols)
            var targetY = row * cellH
            
            if (targetY < gridView.contentY) {
                gridView.contentY = targetY
            } else if (targetY + cellH > gridView.contentY + gridView.height) {
                gridView.contentY = targetY + cellH - gridView.height
            }
        } else {
            var itemHeight = 56
            var spacing = 4
            var targetY = index * (itemHeight + spacing)
            
            if (targetY < listView.contentY) {
                listView.contentY = targetY
            } else if (targetY + itemHeight > listView.contentY + listView.height) {
                listView.contentY = targetY + itemHeight - listView.height
            }
        }
    }
    
    function getFilePathById(fileId) {
        for (var i = 0; i < libraryModel.count; i++) {
            if (libraryModel.getFileIdAt(i) === fileId) {
                return libraryModel.getFilePathAt(i)
            }
        }
        return ""
    }
    
    function batchAITag() {
        var ids = []
        for (var i = 0; i < selectedFileIds.length; i++) {
            ids.push(selectedFileIds[i])
        }
        console.log("Batch AI tag, fileIds:", JSON.stringify(ids))
        root.batchAITagRequested(ids)
    }
    
    function batchManualTag() {
        var ids = []
        for (var i = 0; i < selectedFileIds.length; i++) {
            ids.push(selectedFileIds[i])
        }
        console.log("Batch manual tag, fileIds:", JSON.stringify(ids))
        root.batchManualTagRequested(ids)
    }
}
