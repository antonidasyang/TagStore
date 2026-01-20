import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    property string newFilename: ""
    property string existingPath: ""
    
    // Helper function for translations
    property int _langTrigger: languageManager.updateTrigger
    function t(text) { _langTrigger; return languageManager.t(text) }
    
    signal resolve(int resolution) // 0=Skip, 1=Copy, 2=Alias
    
    spacing: 15
    
    Text {
        text: t("Duplicate File Detected")
        color: themeManager.textPrimary
        font.pixelSize: 18
        font.weight: Font.Bold
    }
    
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
            text: existingPath
            color: themeManager.textMuted
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }
    
    Label {
        text: t("New file: ") + newFilename
        color: themeManager.textPrimary
    }
    
    Label {
        text: t("What would you like to do?")
        color: themeManager.textSecondary
    }
    
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 10
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
                onClicked: resolve(0)
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
                onClicked: resolve(1)
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
                onClicked: resolve(2)
            }
        }
    }
}
