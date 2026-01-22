import QtQuick
import QtQuick.Controls
import Qt.labs.platform as Platform

Window {
    id: dropWindow
    
    // Helper function for translations (depends on updateTrigger for reactivity)
    property int _langTrigger: languageManager.updateTrigger
    function t(text) { _langTrigger; return languageManager.t(text) }
    
    signal requestShowWindow()
    signal requestExit()
    
    width: 100
    height: 100
    x: Screen.width - width - 50
    y: Screen.height - height - 100
    
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    visible: true
    
    Rectangle {
        id: balloon
        
        anchors.centerIn: parent
        width: 70
        height: 70
        radius: 14
        
        color: themeManager.surface
        border.color: isDragOver ? themeManager.primary : themeManager.border
        border.width: isDragOver ? 2 : 1
        
        property bool isDragOver: false
        
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on border.width { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        
        scale: isDragOver ? 1.1 : 1.0
        
        Image {
            anchors.centerIn: parent
            width: 64
            height: 64
            source: "qrc:/icons/icon.png"
            sourceSize.width: 64
            sourceSize.height: 64
            opacity: 1.0
            
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            text: balloon.isDragOver ? t("Release") : ""
            color: themeManager.primary
            font.pixelSize: 11
            font.weight: Font.Bold
            visible: balloon.isDragOver
        }
        
        DropArea {
            anchors.fill: parent
            property int lastButtons: Qt.NoButton
            
            onEntered: function(drag) {
                drag.accepted = drag.hasUrls
                balloon.isDragOver = true
                var btns = fileIngestor.mouseButtons()
                if (btns !== 0) lastButtons = btns
                console.log("Balloon Drag Entered. App Buttons:", btns)
            }
            
            onPositionChanged: function(drag) {
                var btns = fileIngestor.mouseButtons()
                if (btns !== 0) lastButtons = btns
            }
            
            onExited: {
                balloon.isDragOver = false
            }
            
            onDropped: function(drop) {
                balloon.isDragOver = false
                console.log("Balloon Dropped. Last Buttons:", lastButtons, "Proposed Action:", drop.proposedAction)
                
                if (drop.hasUrls) {
                    // Check for Right Button (using cached state) OR Ambiguous action (typical for right-drag on Windows)
                    var isRightButton = (lastButtons & Qt.RightButton)
                    var isAmbiguous = (drop.proposedAction & Qt.MoveAction) && (drop.proposedAction & Qt.CopyAction)
                    
                    if (lastButtons & Qt.RightButton) {
                        console.log("Balloon Right Click Drop -> Show Menu")
                        dropWindow.requestActivate()
                        dropActionMenu.droppedUrls = drop.urls
                        dropActionMenu.open()
                    } else {
                        console.log("Balloon Left Click Drop -> Default Action")
                        var mode = libraryConfig.defaultImportMode
                        if (drop.modifiers & Qt.AltModifier) mode = 1
                        fileIngestor.processDroppedFiles(drop.urls, mode)
                    }
                }
                // Reset
                lastButtons = Qt.NoButton
            }
        }
        
        Platform.Menu {
            id: dropActionMenu
            property var droppedUrls: []
            
            Platform.MenuItem {
                text: t("Move to Library")
                onTriggered: fileIngestor.processDroppedFiles(dropActionMenu.droppedUrls, 0)
            }
            Platform.MenuItem {
                text: t("Link to Original")
                onTriggered: fileIngestor.processDroppedFiles(dropActionMenu.droppedUrls, 1)
            }
            Platform.MenuSeparator {}
            Platform.MenuItem {
                text: t("Cancel")
            }
        }
        
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            
            property point startPos
            
            onPressed: function(mouse) {
                startPos = Qt.point(mouse.x, mouse.y)
            }
            
            onPositionChanged: function(mouse) {
                if (pressedButtons & Qt.LeftButton) {
                    var delta = Qt.point(mouse.x - startPos.x, mouse.y - startPos.y)
                    dropWindow.x += delta.x
                    dropWindow.y += delta.y
                }
            }
            
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    contextMenu.open()
                }
            }
            
            onDoubleClicked: {
                dropWindow.requestShowWindow()
            }
            
            ToolTip.visible: containsMouse && !balloon.isDragOver
            ToolTip.text: t("Drop files and folders here")
            ToolTip.delay: 500
        }
        
        Platform.Menu {
            id: contextMenu
            
            Platform.MenuItem {
                text: t("Show Main Window")
                onTriggered: dropWindow.requestShowWindow()
            }
            
            Platform.MenuItem {
                text: t("Exit")
                onTriggered: dropWindow.requestExit()
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
