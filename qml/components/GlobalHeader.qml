import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    color: themeManager.surface
    
    // Helper function for translations (depends on updateTrigger for reactivity)
    property int _langTrigger: languageManager.updateTrigger
    function t(text) { _langTrigger; return languageManager.t(text) }
    
    signal searchTextChanged(string text)
    signal importClicked()
    signal indexClicked()
    signal settingsClicked()
    
    Behavior on color { ColorAnimation { duration: 200 } }
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 8
        
        // Search box - full width rounded rectangle
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            
            color: themeManager.background
            radius: 8
            border.color: searchField.activeFocus ? themeManager.primary : themeManager.border
            border.width: searchField.activeFocus ? 2 : 1
            
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                
                Text {
                    text: "🔍"
                    font.pixelSize: 14
                    opacity: 0.6
                    Layout.alignment: Qt.AlignVCenter
                }
                
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    placeholderText: t("Search files...")
                    placeholderTextColor: themeManager.textMuted
                    color: themeManager.textPrimary
                    font.pixelSize: 13
                    
                    verticalAlignment: Text.AlignVCenter
                    
                    background: Item {}
                    
                    onTextChanged: {
                        root.searchTextChanged(text)
                    }
                }
                
                // Clear button
                Text {
                    text: "✕"
                    font.pixelSize: 12
                    color: themeManager.textMuted
                    visible: searchField.text.length > 0
                    Layout.alignment: Qt.AlignVCenter
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchField.text = ""
                        }
                    }
                }
            }
        }
        
        // Action buttons (right aligned)
        RowLayout {
            spacing: 6
            
            // Import button (icon only)
            Rectangle {
                id: importBtn
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 8
                
                color: importBtnMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
                scale: importBtnMouse.pressed ? 0.94 : 1.0
                
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                
                Text {
                    anchors.centerIn: parent
                    text: "📥"
                    font.pixelSize: 18
                }
                
                MouseArea {
                    id: importBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.importClicked()
                }
                
                ToolTip.visible: importBtnMouse.containsMouse
                ToolTip.text: t("+ Import")
                ToolTip.delay: 500
            }
            
            // Index button (icon only)
            Rectangle {
                id: indexBtn
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 8
                
                color: indexBtnMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                border.color: themeManager.border
                border.width: 1
                scale: indexBtnMouse.pressed ? 0.94 : 1.0
                
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                
                Text {
                    anchors.centerIn: parent
                    text: "🔗"
                    font.pixelSize: 18
                }
                
                MouseArea {
                    id: indexBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.indexClicked()
                }
                
                ToolTip.visible: indexBtnMouse.containsMouse
                ToolTip.text: t("🔗 Index")
                ToolTip.delay: 500
            }
            
            // Settings button
            Rectangle {
                id: settingsBtn
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 8
                
                color: settingsBtnMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                border.color: themeManager.border
                border.width: 1
                scale: settingsBtnMouse.pressed ? 0.94 : 1.0
                
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                
                Text {
                    anchors.centerIn: parent
                    text: "⚙️"
                    font.pixelSize: 18
                }
                
                MouseArea {
                    id: settingsBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.settingsClicked()
                }
                
                ToolTip.visible: settingsBtnMouse.containsMouse
                ToolTip.text: t("Settings")
                ToolTip.delay: 500
            }
        }
    }
    
    // Bottom border
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: themeManager.border
        
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}
