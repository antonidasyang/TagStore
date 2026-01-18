import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    property int tagId: -1
    property string tagName: ""
    property bool isSelected: false
    property bool isAIGenerated: false
    
    signal clicked()
    
    width: chipContent.width + 16
    height: 26
    radius: 4
    
    color: isSelected ? themeManager.primary : (chipMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface)
    border.color: isAIGenerated ? themeManager.purple : (isSelected ? themeManager.primary : themeManager.border)
    border.width: isAIGenerated ? 2 : 1
    scale: chipMouse.pressed ? 0.95 : 1.0
    
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 100 } }
    
    Row {
        id: chipContent
        anchors.centerIn: parent
        spacing: 4
        
        // AI sparkle indicator
        Text {
            text: "✨"
            font.pixelSize: 10
            visible: root.isAIGenerated
            anchors.verticalCenter: parent.verticalCenter
        }
        
        Text {
            text: root.tagName
            color: root.isSelected ? "white" : themeManager.textSecondary
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
            
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    
    MouseArea {
        id: chipMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        
        onClicked: root.clicked()
    }
}
