import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    property alias asItemChecked: asItemRadio.checked
    property alias recursiveChecked: recursiveRadio.checked
    
    // Helper function for translations
    property int _langTrigger: languageManager.updateTrigger
    function t(text) { _langTrigger; return languageManager.t(text) }
    
    signal cancel()
    signal ok()
    
    spacing: 20
    
    Text {
        text: t("Import Folders")
        color: themeManager.textPrimary
        font.pixelSize: 18
        font.weight: Font.Bold
    }
    
    Text {
        text: t("Folders detected. How would you like to import them?")
        color: themeManager.textSecondary
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }
    
    ButtonGroup { id: folderOptionGroup }
    
    RadioButton {
        id: asItemRadio
        text: t("Import as Single Items (Reference)")
        checked: true
        ButtonGroup.group: folderOptionGroup
    }
    
    RadioButton {
        id: recursiveRadio
        text: t("Scan Contents Recursively")
        ButtonGroup.group: folderOptionGroup
    }
    
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        
        Item { Layout.fillWidth: true }
        
        Rectangle {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 36
            radius: 8
            color: cancelFolderMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
            border.color: themeManager.border
            
            Text {
                anchors.centerIn: parent
                text: t("Cancel")
                color: themeManager.textSecondary
            }
            
            MouseArea {
                id: cancelFolderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cancel()
            }
        }
        
        Rectangle {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 36
            radius: 8
            color: okFolderMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
            
            Text {
                anchors.centerIn: parent
                text: t("OK")
                color: "white"
            }
            
            MouseArea {
                id: okFolderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ok()
            }
        }
    }
}
