import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    property int fileId: -1
    property string filename: ""
    property string filePath: ""
    property bool isReferenced: false
    property bool isAITagged: false
    property var tags: []
    
    // Selection support
    property bool isSelected: false
    property bool isFocused: false  // Keyboard focus indicator
    
    signal clicked(bool ctrlKey, bool shiftKey)
    signal rightClicked(real mouseX, real mouseY)
    signal tagClicked(string tagName)
    signal doubleClicked()
    
    radius: 12
    color: isSelected ? themeManager.primaryLight : themeManager.surface
    border.color: {
        if (isSelected) return themeManager.primary
        if (isFocused) return themeManager.primary
        if (mouseArea.containsMouse) return themeManager.primary
        return themeManager.border
    }
    border.width: {
        if (isSelected || isFocused) return 2
        if (mouseArea.containsMouse) return 2
        return 1
    }
    scale: mouseArea.pressed ? 0.98 : 1.0
    
    // Fixed height - no expansion
    height: 170
    
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on border.width { NumberAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6
        
        // Thumbnail area
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            
            radius: 8
            color: themeManager.background
            
            Behavior on color { ColorAnimation { duration: 200 } }
            
            // File type icon
            Text {
                anchors.centerIn: parent
                text: getFileIcon(root.filename)
                font.pixelSize: 36
                opacity: 0.9
            }
            
            // Overlay indicators (top right)
            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 5
                spacing: 4
                
                // Reference indicator
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: themeManager.success
                    visible: root.isReferenced
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🔗"
                        font.pixelSize: 10
                    }
                }
                
                // AI tagged indicator
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: themeManager.purple
                    visible: root.isAITagged
                    
                    Text {
                        anchors.centerIn: parent
                        text: "✨"
                        font.pixelSize: 10
                    }
                }
            }
        }
        
        // Filename
        Text {
            Layout.fillWidth: true
            text: root.filename
            color: themeManager.textPrimary
            font.pixelSize: 11
            font.weight: Font.Medium
            elide: Text.ElideMiddle
            maximumLineCount: 2
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        
        // Tags - single row with expand button
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            Row {
                id: tagsRow
                anchors.fill: parent
                spacing: 3
                clip: true
                
                Repeater {
                    id: visibleTagsRepeater
                    model: root.tags.slice(0, getVisibleTagCount())
                    
                    Rectangle {
                        width: Math.min(tagText.implicitWidth + 10, 70)
                        height: 20
                        radius: 4
                        color: tagItemMouse.containsMouse ? themeManager.primary : themeManager.primaryLight
                        border.color: themeManager.primary
                        border.width: 0.5
                        opacity: 0.9
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        Text {
                            id: tagText
                            anchors.centerIn: parent
                            width: parent.width - 8
                            text: modelData
                            color: tagItemMouse.containsMouse ? "white" : themeManager.primary
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        MouseArea {
                            id: tagItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tagClicked(modelData)
                        }
                    }
                }
                
                // Expand button if more tags
                Rectangle {
                    id: expandBtn
                    visible: root.tags.length > getVisibleTagCount()
                    width: moreText.width + 10
                    height: 20
                    radius: 4
                    color: expandTagsMouse.containsMouse ? themeManager.primary : themeManager.surfaceHover
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Text {
                        id: moreText
                        anchors.centerIn: parent
                        text: "+" + (root.tags.length - getVisibleTagCount())
                        color: expandTagsMouse.containsMouse ? "white" : themeManager.textMuted
                        font.pixelSize: 11
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    
                    MouseArea {
                        id: expandTagsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tagsPopup.open()
                        }
                    }
                }
            }
        }
    }
    
    // Floating popup for all tags
    Popup {
        id: tagsPopup
        x: 0
        y: root.height - 10
        width: Math.max(root.width, tagsPopupFlow.implicitWidth + 24)
        height: Math.min(tagsPopupFlow.implicitHeight + 40, 200)
        
        padding: 12
        
        background: Rectangle {
            color: themeManager.surface
            radius: 10
            border.color: themeManager.primary
            border.width: 1
            
            layer.enabled: true
            layer.effect: Item {
                // Shadow effect simulation
            }
        }
        
        // Close on click outside
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 8
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    text: languageManager.t("All Tags") + " (" + root.tags.length + ")"
                    color: themeManager.textSecondary
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: closePopupMouse.containsMouse ? themeManager.surfaceHover : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: themeManager.textMuted
                        font.pixelSize: 12
                    }
                    
                    MouseArea {
                        id: closePopupMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tagsPopup.close()
                    }
                }
            }
            
            // Tags flow
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: tagsPopupFlow.width
                contentHeight: tagsPopupFlow.height
                clip: true
                
                Flow {
                    id: tagsPopupFlow
                    width: tagsPopup.width - 24
                    spacing: 6
                    
                    Repeater {
                        model: root.tags
                        
                        Rectangle {
                            width: popupTagText.implicitWidth + 12
                            height: 24
                            radius: 4
                            color: popupTagMouse.containsMouse ? themeManager.primary : themeManager.primaryLight
                            border.color: themeManager.primary
                            border.width: 0.5
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            Text {
                                id: popupTagText
                                anchors.centerIn: parent
                                text: modelData
                                color: popupTagMouse.containsMouse ? "white" : themeManager.primary
                                font.pixelSize: 12
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            
                            MouseArea {
                                id: popupTagMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.tagClicked(modelData)
                                    tagsPopup.close()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
            NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutQuad }
        }
        
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        propagateComposedEvents: true
        
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked(mouse.x, mouse.y)
            } else {
                // Left click - pass modifier key states
                var ctrlKey = (mouse.modifiers & Qt.ControlModifier) !== 0
                var shiftKey = (mouse.modifiers & Qt.ShiftModifier) !== 0
                root.clicked(ctrlKey, shiftKey)
            }
        }
        
        onDoubleClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.doubleClicked()
            }
        }
    }
    
    function getVisibleTagCount() {
        // Calculate how many tags can fit in one row
        // Assuming avg tag width of 60px and spacing of 3px
        var availableWidth = root.width - 20  // margins
        var avgTagWidth = 55
        var expandBtnWidth = 35
        
        if (root.tags.length <= 2) {
            return root.tags.length
        }
        
        var count = Math.floor((availableWidth - expandBtnWidth) / (avgTagWidth + 3))
        return Math.max(1, Math.min(count, root.tags.length))
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
