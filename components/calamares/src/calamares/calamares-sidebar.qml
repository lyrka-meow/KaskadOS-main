/* SPDX-License-Identifier: GPL-3.0-or-later */

import io.calamares.ui 1.0
import io.calamares.core 1.0
import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: sideBar
    color: "#161B18"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 20
            spacing: 12

            Rectangle {
                width: 52
                height: 52
                radius: 18
                color: "#23352A"

                Image {
                    anchors.centerIn: parent
                    width: 34
                    height: 34
                    source: "file:/" + Branding.imagePath(Branding.ProductLogo)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            ColumnLayout {
                spacing: 1

                Text {
                    text: "KaskadOS"
                    color: "#F1F5F2"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Установка системы"
                    color: "#9EAAA2"
                    font.pixelSize: 12
                }
            }
        }

        Repeater {
            model: ViewManager

            Rectangle {
                required property int index
                required property string display

                Layout.fillWidth: true
                height: 44
                radius: 14
                color: index === ViewManager.currentStepIndex ? "#31483A" : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: index <= ViewManager.currentStepIndex ? "#9FE0B4" : "#566159"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 34
                        text: display
                        color: index === ViewManager.currentStepIndex ? "#D8F8E2" : "#C4CCC7"
                        font.pixelSize: 15
                        font.weight: index === ViewManager.currentStepIndex ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#343C37"
        }

        Text {
            Layout.topMargin: 6
            Layout.fillWidth: true
            text: "KaskadOS Rolling"
            color: "#77817B"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
