import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    
    modal: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: parent
    width: 560
    height: 600
    
    leftPadding: 32
    rightPadding: 32
    topPadding: 32
    bottomPadding: 32
    
    Shortcut {
        sequence: "Esc"
        enabled: root.visible
        onActivated: root.close()
    }
    
    // Helper function for translations
    property int _langTrigger: languageManager.updateTrigger
    function t(text) { _langTrigger; return languageManager.t(text) }
    
    property var allTags: []
    property var filteredTags: []
    property var selectedTagIds: []
    
    onOpened: {
        refreshTags()
    }
    
    function refreshTags() {
        allTags = databaseManager.getAllTags()
        filterTags()
        selectedTagIds = []
    }
    
    function filterTags() {
        if (searchField.text.trim() === "") {
            filteredTags = allTags
        } else {
            var k = searchField.text.toLowerCase()
            filteredTags = allTags.filter(function(t) { return t.name.toLowerCase().indexOf(k) !== -1 })
        }
    }
    
    function toggleSelection(tagId) {
        var idx = selectedTagIds.indexOf(tagId)
        if (idx === -1) {
            selectedTagIds.push(tagId)
        } else {
            selectedTagIds.splice(idx, 1)
        }
        selectedTagIds = selectedTagIds.slice() // Trigger update
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
            text: t("Global Tag Manager")
            color: themeManager.textPrimary
            font.pixelSize: 18
            font.weight: Font.Bold
        }
        
        // Search
        TextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: t("Search tags...")
            color: themeManager.textPrimary
            placeholderTextColor: themeManager.textMuted
            
            background: Rectangle {
                color: themeManager.background
                radius: 8
                border.color: searchField.activeFocus ? themeManager.primary : themeManager.border
            }
            
            onTextChanged: root.filterTags()
        }
        
        // Tag List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: themeManager.background
            radius: 8
            border.color: themeManager.border
            
            Flickable {
                anchors.fill: parent
                anchors.margins: 12
                contentWidth: width
                contentHeight: tagsFlow.height
                clip: true
                
                Flow {
                    id: tagsFlow
                    width: parent.width
                    spacing: 8
                    
                    Repeater {
                        model: root.filteredTags
                        
                        Rectangle {
                            property bool isSelected: root.selectedTagIds.indexOf(modelData.id) !== -1
                            
                            width: tagText.implicitWidth + 24
                            height: 32
                            radius: 16
                            color: isSelected ? themeManager.primary : (itemMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface)
                            border.color: isSelected ? themeManager.primary : themeManager.border
                            border.width: 1
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            Text {
                                id: tagText
                                anchors.centerIn: parent
                                text: modelData.name + " (" + modelData.count + ")"
                                color: isSelected ? "white" : themeManager.textPrimary
                                font.pixelSize: 13
                            }
                            
                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleSelection(modelData.id)
                            }
                        }
                    }
                }
            }
        }
        
        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Item { Layout.fillWidth: true }
            
            // Remove Empty Tags button
            Rectangle {
                id: removeEmptyBtn
                Layout.preferredWidth: removeEmptyText.implicitWidth + 24
                Layout.preferredHeight: 36
                radius: 8
                color: removeEmptyMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                border.color: themeManager.border
                
                Text {
                    id: removeEmptyText
                    anchors.centerIn: parent
                    text: t("Remove Empty Tags")
                    color: themeManager.textSecondary
                    font.pixelSize: 13
                }
                
                MouseArea {
                    id: removeEmptyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: removeEmptyConfirmDialog.open()
                }
            }
            
            // Delete button
            Rectangle {
                id: deleteBtn
                property bool isEnabled: root.selectedTagIds.length > 0
                Layout.preferredWidth: 80
                Layout.preferredHeight: 36
                radius: 8
                color: isEnabled ? (deleteMouse.containsMouse ? "#dc2626" : "#ef4444") : themeManager.surface
                border.color: isEnabled ? "transparent" : themeManager.border
                opacity: isEnabled ? 1.0 : 0.5
                
                Text {
                    anchors.centerIn: parent
                    text: t("Delete")
                    color: isEnabled ? "white" : themeManager.textMuted
                    font.pixelSize: 13
                }
                
                MouseArea {
                    id: deleteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: deleteBtn.isEnabled
                    cursorShape: deleteBtn.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: deleteConfirmDialog.open()
                }
            }
            
            // Rename button
            Rectangle {
                id: renameBtnAction
                property bool isEnabled: root.selectedTagIds.length === 1
                Layout.preferredWidth: 80
                Layout.preferredHeight: 36
                radius: 8
                color: isEnabled ? (renameMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface) : themeManager.surface
                border.color: themeManager.border
                opacity: isEnabled ? 1.0 : 0.5
                
                Text {
                    anchors.centerIn: parent
                    text: t("Rename")
                    color: isEnabled ? themeManager.textPrimary : themeManager.textMuted
                    font.pixelSize: 13
                }
                
                MouseArea {
                    id: renameMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: renameBtnAction.isEnabled
                    cursorShape: renameBtnAction.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        renameDialog.tagId = root.selectedTagIds[0]
                        var tag = root.allTags.find(function(t) { return t.id === root.selectedTagIds[0] })
                        renameDialog.oldName = tag ? tag.name : ""
                        renameDialog.open()
                    }
                }
            }
            
            // Merge button
            Rectangle {
                id: mergeBtnAction
                property bool isEnabled: root.selectedTagIds.length > 1
                Layout.preferredWidth: 80
                Layout.preferredHeight: 36
                radius: 8
                color: isEnabled ? (mergeMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface) : themeManager.surface
                border.color: themeManager.border
                opacity: isEnabled ? 1.0 : 0.5
                
                Text {
                    anchors.centerIn: parent
                    text: t("Merge")
                    color: isEnabled ? themeManager.textPrimary : themeManager.textMuted
                    font.pixelSize: 13
                }
                
                MouseArea {
                    id: mergeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: mergeBtnAction.isEnabled
                    cursorShape: mergeBtnAction.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        mergeDialog.sourceIds = root.selectedTagIds
                        mergeDialog.open()
                    }
                }
            }
            
            // Close button
            Rectangle {
                id: closeBtnAction
                Layout.preferredWidth: 80
                Layout.preferredHeight: 36
                radius: 8
                color: closeMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                border.color: themeManager.border
                
                Text {
                    anchors.centerIn: parent
                    text: t("Close")
                    color: themeManager.textPrimary
                    font.pixelSize: 13
                }
                
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }
    }
    
    // Delete Confirm
    Dialog {
        id: removeEmptyConfirmDialog
        modal: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent
        width: 350
        padding: 24
        
        Shortcut {
            sequence: "Esc"
            enabled: removeEmptyConfirmDialog.visible
            onActivated: removeEmptyConfirmDialog.close()
        }
        
        background: Rectangle { color: themeManager.surface; radius: 12; border.color: themeManager.border }
        
        ColumnLayout {
            spacing: 16
            
            Text {
                text: t("Remove Empty Tags")
                color: themeManager.textPrimary
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            
            Text {
                text: t("Are you sure you want to remove all unused tags?")
                color: themeManager.textPrimary
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: cancelRemoveMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                    border.color: themeManager.border
                    Text { anchors.centerIn: parent; text: t("Cancel"); color: themeManager.textSecondary }
                    MouseArea { id: cancelRemoveMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: removeEmptyConfirmDialog.close() }
                }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: okRemoveMouse.containsMouse ? "#dc2626" : "#ef4444"
                    Text { anchors.centerIn: parent; text: t("Delete"); color: "white" }
                    MouseArea {
                        id: okRemoveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            databaseManager.removeEmptyTags()
                            root.refreshTags()
                            removeEmptyConfirmDialog.close()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: deleteConfirmDialog
        modal: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent
        width: 350
        padding: 24
        
        Shortcut {
            sequence: "Esc"
            enabled: deleteConfirmDialog.visible
            onActivated: deleteConfirmDialog.close()
        }
        
        background: Rectangle { color: themeManager.surface; radius: 12; border.color: themeManager.border }
        
        ColumnLayout {
            spacing: 16
            
            Text {
                text: t("Delete Tag")
                color: themeManager.textPrimary
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            
            Text {
                text: t("Are you sure you want to delete these tags?") + "\n" + t("This action cannot be undone.")
                color: themeManager.textPrimary
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: cancelDeleteMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                    border.color: themeManager.border
                    Text { anchors.centerIn: parent; text: t("Cancel"); color: themeManager.textSecondary }
                    MouseArea { id: cancelDeleteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deleteConfirmDialog.close() }
                }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: okDeleteMouse.containsMouse ? "#dc2626" : "#ef4444"
                    Text { anchors.centerIn: parent; text: t("Delete"); color: "white" }
                    MouseArea {
                        id: okDeleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            for (var i = 0; i < root.selectedTagIds.length; i++) {
                                databaseManager.deleteTag(root.selectedTagIds[i])
                            }
                            root.refreshTags()
                            deleteConfirmDialog.close()
                        }
                    }
                }
            }
        }
    }
    
    // Rename Dialog
    Dialog {
        id: renameDialog
        property int tagId: -1
        property string oldName: ""
        
        modal: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent
        width: 350
        padding: 24
        
        Shortcut {
            sequence: "Esc"
            enabled: renameDialog.visible
            onActivated: renameDialog.close()
        }
        
        background: Rectangle { color: themeManager.surface; radius: 12; border.color: themeManager.border }
        
        onOpened: {
            renameField.text = oldName
            renameField.forceActiveFocus()
        }
        
        ColumnLayout {
            spacing: 16
            
            Text {
                text: t("Rename Tag")
                color: themeManager.textPrimary
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            
            TextField {
                id: renameField
                Layout.fillWidth: true
                placeholderText: t("New Name")
                onAccepted: renameBtn.clicked()
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: cancelRenameMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                    border.color: themeManager.border
                    Text { anchors.centerIn: parent; text: t("Cancel"); color: themeManager.textSecondary }
                    MouseArea { id: cancelRenameMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: renameDialog.close() }
                }
                
                Rectangle {
                    id: renameBtn
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: renameBtnMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
                    Text { anchors.centerIn: parent; text: t("Rename"); color: "white" }
                    MouseArea {
                        id: renameBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (renameField.text.trim() !== "") {
                                databaseManager.renameTag(renameDialog.tagId, renameField.text)
                                root.refreshTags()
                                renameDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Merge Dialog
    Dialog {
        id: mergeDialog
        property var sourceIds: []
        property int targetId: -1
        
        modal: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent
        width: 400
        padding: 24
        
        Shortcut {
            sequence: "Esc"
            enabled: mergeDialog.visible
            onActivated: mergeDialog.close()
        }
        
        background: Rectangle { color: themeManager.surface; radius: 12; border.color: themeManager.border }
        
        ColumnLayout {
            spacing: 16
            
            Text {
                text: t("Merge Tags")
                color: themeManager.textPrimary
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            
            Text {
                text: t("Merge selected tags into:")
                color: themeManager.textPrimary
            }
            
            ComboBox {
                id: targetCombo
                Layout.fillWidth: true
                textRole: "name"
                valueRole: "id"
                // Model should be all tags (user can merge into one of selected or another)
                model: root.allTags
                
                onActivated: {
                    mergeDialog.targetId = currentValue
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
                    color: cancelMergeMouse.containsMouse ? themeManager.surfaceHover : themeManager.surface
                    border.color: themeManager.border
                    Text { anchors.centerIn: parent; text: t("Cancel"); color: themeManager.textSecondary }
                    MouseArea { id: cancelMergeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mergeDialog.close() }
                }
                
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 8
                    color: okMergeMouse.containsMouse ? themeManager.primaryHover : themeManager.primary
                    Text { anchors.centerIn: parent; text: t("Merge"); color: "white" }
                    MouseArea {
                        id: okMergeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (targetCombo.currentValue !== undefined) {
                                databaseManager.mergeTags(targetCombo.currentValue, mergeDialog.sourceIds)
                                root.refreshTags()
                                mergeDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
