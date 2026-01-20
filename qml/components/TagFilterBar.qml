import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    color: themeManager.background
    
    // Helper function for translations
    property int _langTrigger: languageManager.updateTrigger
    function t(text) { _langTrigger; return languageManager.t(text) }
    
    property var selectedTagIds: []
    property var selectedTagNames: []  // Store names for display
    property var recommendedTags: libraryModel.recommendedTags   // Bound to C++ model
    
    signal tagSelectionChanged(var tagIds)
    signal tagRemoved(int tagId)
    signal tagAdded(int tagId, string tagName)
    
    Behavior on color { ColorAnimation { duration: 200 } }
    
    // Check if there's anything to show
    property bool hasContent: selectedTagIds.length > 0 || recommendedTags.length > 0
    
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 4
        
        // Row 1: Active filter tags (with close button)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: selectedTagIds.length > 0
            
            Text {
                text: t("Filters:")
                color: themeManager.textMuted
                font.pixelSize: 12
            }
            
            Flow {
                Layout.fillWidth: true
                spacing: 6
                
                Repeater {
                    model: root.selectedTagIds.length
                    
                    Rectangle {
                        width: activeTagText.width + 28
                        height: 24
                        radius: 4
                        color: themeManager.primary
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 4
                            spacing: 4
                            
                            Text {
                                id: activeTagText
                                text: root.selectedTagNames[index] || ""
                                color: "white"
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignVCenter
                            }
                            
                            // Close button
                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                color: closeTagMouse.containsMouse ? Qt.rgba(1,1,1,0.3) : "transparent"
                                Layout.alignment: Qt.AlignVCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: "white"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                
                                MouseArea {
                                    id: closeTagMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var tagId = root.selectedTagIds[index]
                                        root.removeTag(tagId)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Clear all button
            Rectangle {
                visible: root.selectedTagIds.length > 1
                width: clearAllText.width + 12
                height: 24
                radius: 4
                color: clearAllMouse.containsMouse ? themeManager.surfaceHover : "transparent"
                
                Text {
                    id: clearAllText
                    anchors.centerIn: parent
                    text: t("Clear All")
                    color: themeManager.textMuted
                    font.pixelSize: 11
                }
                
                MouseArea {
                    id: clearAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedTagIds = []
                        root.selectedTagNames = []
                        root.tagSelectionChanged([])
                    }
                }
            }
        }
        
        // Row 2: Recommended tags from search results
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: recommendedTags.length > 0
            
            Text {
                text: t("Suggested:")
                color: themeManager.textMuted
                font.pixelSize: 12
            }
            
            Flow {
                Layout.fillWidth: true
                spacing: 6
                
                Repeater {
                    model: recommendedTags
                    
                    Rectangle {
                        width: suggestTagText.width + 12
                        height: 24
                        radius: 4
                        color: suggestTagMouse.containsMouse ? themeManager.primaryLight : themeManager.surface
                        border.color: themeManager.border
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        Text {
                            id: suggestTagText
                            anchors.centerIn: parent
                            text: modelData.name + " (" + modelData.count + ")"
                            color: themeManager.textSecondary
                            font.pixelSize: 11
                        }
                        
                        MouseArea {
                            id: suggestTagMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.addTag(modelData.id, modelData.name)
                            }
                        }
                    }
                }
            }
        }
        
        // Empty state - just show label
        RowLayout {
            Layout.fillWidth: true
            visible: !hasContent
            
            Text {
                text: t("Tags:")
                color: themeManager.textMuted
                font.pixelSize: 12
            }
            
            Text {
                text: t("Click tags on files or search to filter")
                color: themeManager.textMuted
                font.pixelSize: 11
                opacity: 0.6
            }
            
            Item { Layout.fillWidth: true }
        }
    }
    
    // Bottom border
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: themeManager.border
    }
    
    // Functions to manage tags
    function addTag(tagId, tagName) {
        if (selectedTagIds.indexOf(tagId) === -1) {
            selectedTagIds.push(tagId)
            selectedTagNames.push(tagName)
            selectedTagIds = selectedTagIds.slice()
            selectedTagNames = selectedTagNames.slice()
            tagSelectionChanged(selectedTagIds)
            tagAdded(tagId, tagName)
        }
    }
    
    function removeTag(tagId) {
        var idx = selectedTagIds.indexOf(tagId)
        if (idx !== -1) {
            selectedTagIds.splice(idx, 1)
            selectedTagNames.splice(idx, 1)
            selectedTagIds = selectedTagIds.slice()
            selectedTagNames = selectedTagNames.slice()
            tagSelectionChanged(selectedTagIds)
            tagRemoved(tagId)
        }
    }
    
    function clearAll() {
        selectedTagIds = []
        selectedTagNames = []
        tagSelectionChanged([])
    }
}
