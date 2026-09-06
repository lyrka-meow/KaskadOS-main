/* SPDX-License-Identifier: GPL-3.0-or-later */

import io.calamares.ui 1.0
import io.calamares.core 1.0
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: navigationBar
    color: "#111512"
    height: 72

    component ActionButton: Button {
        id: control
        implicitHeight: 44
        implicitWidth: Math.max(120, contentItem.implicitWidth + 40)

        contentItem: Text {
            text: control.text
            color: control.enabled
                ? (control.highlighted ? "#102117" : "#E2E8E4")
                : "#68716B"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 15
            color: !control.enabled
                ? "#202522"
                : (control.highlighted
                    ? (control.down ? "#8BC9A0" : "#9FE0B4")
                    : (control.down ? "#303833" : "#272D29"))
            border.width: control.highlighted ? 0 : 1
            border.color: "#414943"
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        spacing: 12

        ActionButton {
            text: ViewManager.quitLabel
            enabled: ViewManager.quitEnabled
            visible: ViewManager.quitVisible
            onClicked: ViewManager.quit()
        }

        Item { Layout.fillWidth: true }

        ActionButton {
            text: ViewManager.backLabel
            enabled: ViewManager.backEnabled
            visible: ViewManager.backAndNextVisible
            onClicked: ViewManager.back()
        }

        ActionButton {
            text: ViewManager.nextLabel
            highlighted: true
            enabled: ViewManager.nextEnabled
            visible: ViewManager.backAndNextVisible
            onClicked: ViewManager.next()
        }
    }
}
