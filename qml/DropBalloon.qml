import QtQuick
import QtQuick.Controls
import Qt.labs.platform

Window {
    id: dropWindow
    
    // Helper function for translations (depends on updateTrigger for reactivity)
    property int _langTrigger: languageManager.updateTrigger
    function t(text) { _langTrigger; return languageManager.t(text) }
    
    width: 200
    height: 200
    x: Screen.width - width - 50
    y: Screen.height - height - 100
    
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowTransparentForInput
    color: "transparent"
    visible: true
    
    Rectangle {
        id: balloon
        
        anchors.centerIn: parent
        width: 160
        height: 160
        radius: 80
        
        color: themeManager.surface
        border.color: isDragOver ? themeManager.primary : themeManager.border
        border.width: isDragOver ? 3 : 1
        
        property bool isDragOver: false
        
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on border.width { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        
        scale: isDragOver ? 1.1 : 1.0
        
        layer.enabled: true
        layer.effect: Item {
            property var source
            
            Rectangle {
                anchors.fill: parent
                anchors.margins: -10
                radius: balloon.radius + 10
                color: "transparent"
                
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    height: parent.height - 20
                    radius: balloon.radius
                    color: themeManager.shadow
                }
            }
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 10
            
            Text {
                text: balloon.isDragOver ? "📥" : "📦"
                font.pixelSize: 48
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: balloon.isDragOver ? t("Release") : t("Drop Here")
                color: themeManager.textPrimary
                font.pixelSize: 14
                font.weight: Font.Medium
                anchors.horizontalCenter: parent.horizontalCenter
                
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
        
        DropArea {
            anchors.fill: parent
            
            onEntered: function(drag) {
                drag.accepted = drag.hasUrls
                balloon.isDragOver = true
                dropWindow.flags = Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
            }
            
            onExited: {
                balloon.isDragOver = false
                dropWindow.flags = Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowTransparentForInput
            }
            
            onDropped: function(drop) {
                balloon.isDragOver = false
                dropWindow.flags = Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowTransparentForInput
                
                if (drop.hasUrls) {
                    var mode = drop.modifiers & Qt.AltModifier ? 1 : 0
                    fileIngestor.processDroppedFiles(drop.urls, mode)
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            
            onClicked: {
                dropWindow.flags = Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowTransparentForInput
            }
        }
    }
    
    NumberAnimation {
        id: pulseAnimation
        target: balloon
        property: "opacity"
        from: 0.9
        to: 1.0
        duration: 1500
        loops: Animation.Infinite
        running: true
        easing.type: Easing.InOutSine
    }
}
