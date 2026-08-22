/*
    SPDX-License-Identifier: GPL-3.0-or-later
    SPDX-FileCopyrightText: 2026 The MacqueenDE contributors
*/

import Macqueen.Ipc
import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Scope {
    id: controller

    property bool chooserOpen: false
    property string requestId: ""
    property string chooserTitle: ""
    property var choices: []
    property bool allowRestore: true
    property int selectedIndex: -1

    function closeChooser() {
        chooserOpen = false;
        requestId = "";
        choices = [];
        selectedIndex = -1;
    }

    function cancel() {
        const pendingRequest = requestId;
        closeChooser();
        if (pendingRequest.length > 0)
            Macqueen.cancelScreenCastSelection(pendingRequest);
    }

    function accept() {
        if (selectedIndex < 0 || selectedIndex >= choices.length)
            return;
        const pendingRequest = requestId;
        const choice = choices[selectedIndex];
        if (Macqueen.submitScreenCastSelection(pendingRequest, choice.kind, choice.id, allowRestore))
            closeChooser();
    }

    Connections {
        target: Macqueen

        function onScreenCastSelectionRequested(newRequestId, newTitle, optionsJson) {
            let options = {};
            try {
                options = JSON.parse(optionsJson);
            } catch (error) {
                console.warn("Invalid Macqueen screencast request:", error);
                Macqueen.cancelScreenCastSelection(newRequestId);
                return;
            }
            controller.requestId = newRequestId;
            controller.chooserTitle = newTitle;
            controller.choices = (options.outputs || []).concat(options.windows || []);
            controller.allowRestore = true;
            controller.selectedIndex = controller.choices.length === 1 ? 0 : -1;
            controller.chooserOpen = true;
        }
    }

    FloatingWindow {
        id: window

            readonly property int chooserWidth: 760
            readonly property int chooserHeight: screen ? Math.min(680, screen.height - 80) : 680

            objectName: "macqueenScreenCastChooser"
            title: controller.chooserTitle
            minimumSize: Qt.size(chooserWidth, Math.min(chooserHeight, 480))
            maximumSize: Qt.size(chooserWidth, chooserHeight)
            color: Theme.surfaceContainer
            visible: controller.chooserOpen

            onClosed: controller.cancel()

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: event => {
                    controller.cancel();
                    event.accepted = true;
                }
                Keys.onReturnPressed: event => {
                    controller.accept();
                    event.accepted = true;
                }
                Keys.onEnterPressed: event => {
                    controller.accept();
                    event.accepted = true;
                }
                Keys.onUpPressed: event => {
                    controller.selectedIndex = Math.max(0, controller.selectedIndex - 1);
                    choicesView.positionViewAtIndex(controller.selectedIndex, ListView.Contain);
                    event.accepted = true;
                }
                Keys.onDownPressed: event => {
                    controller.selectedIndex = Math.min(controller.choices.length - 1, controller.selectedIndex + 1);
                    choicesView.positionViewAtIndex(controller.selectedIndex, ListView.Contain);
                    event.accepted = true;
                }

                Item {
                    id: header
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingL
                    height: 66

                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: windowButtons.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        onPressed: windowControls.tryStartMove()
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: windowButtons.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: Theme.spacingM
                        spacing: 4

                        StyledText {
                            width: parent.width
                            text: controller.chooserTitle
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: "Выберите экран или окно для демонстрации"
                            color: Theme.surfaceTextMedium
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    Row {
                        id: windowButtons
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankActionButton {
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: controller.cancel()
                        }
                    }
                }

                Rectangle {
                    id: listBackground
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: header.bottom
                    anchors.bottom: footer.top
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingL
                    anchors.topMargin: Theme.spacingS
                    anchors.bottomMargin: Theme.spacingM
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Theme.outline

                    ListView {
                        id: choicesView
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        clip: true
                        spacing: Theme.spacingS
                        model: controller.choices

                        delegate: Rectangle {
                            id: choiceCard

                            required property int index
                            required property var modelData
                            width: choicesView.width
                            height: 76
                            radius: Theme.cornerRadius
                            color: controller.selectedIndex === index ? Theme.primaryContainer : Theme.surfaceContainer
                            border.width: controller.selectedIndex === index ? 2 : 1
                            border.color: controller.selectedIndex === index ? Theme.primary : Theme.outline

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44
                                    height: 44
                                    radius: 12
                                    color: controller.selectedIndex === choiceCard.index ? Theme.primary : Theme.surfaceContainerHighest

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: choiceCard.modelData.kind === "window" ? "▣" : "▰"
                                        color: controller.selectedIndex === choiceCard.index ? Theme.primaryText : Theme.surfaceText
                                        font.pixelSize: 22
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 60
                                    spacing: 4

                                    StyledText {
                                        width: parent.width
                                        text: choiceCard.modelData.label || choiceCard.modelData.name || choiceCard.modelData.id
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: choiceCard.modelData.kind === "window"
                                            ? "Окно · " + (choiceCard.modelData.appId || "приложение")
                                            : "Экран · " + (choiceCard.modelData.name || choiceCard.modelData.description || "")
                                        color: Theme.surfaceTextMedium
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controller.selectedIndex = choiceCard.index
                                onDoubleClicked: {
                                    controller.selectedIndex = choiceCard.index;
                                    controller.accept();
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: controller.choices.length === 0
                            text: "Нет доступных экранов или окон"
                            color: Theme.surfaceTextMedium
                        }
                    }
                }

                Item {
                    id: footer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacingL
                    height: 48

                    DankButton {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: controller.allowRestore ? "✓  Запомнить выбор" : "Запомнить выбор"
                        backgroundColor: Theme.surfaceContainerHighest
                        textColor: Theme.surfaceText
                        onClicked: controller.allowRestore = !controller.allowRestore
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        DankButton {
                            text: "Отмена"
                            backgroundColor: Theme.surfaceContainerHighest
                            textColor: Theme.surfaceText
                            onClicked: controller.cancel()
                        }

                        DankButton {
                            text: "Поделиться"
                            enabled: controller.selectedIndex >= 0
                            backgroundColor: enabled ? Theme.primary : Theme.surfaceContainerHighest
                            textColor: enabled ? Theme.primaryText : Theme.surfaceTextMedium
                            onClicked: controller.accept()
                        }
                    }
                }
            }

        FloatingWindowControls {
            id: windowControls
            targetWindow: window
        }
    }
}
