pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: qsTr("AI Providers")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        SectionHeader {
            first: true
            text: qsTr("Configured Providers")
        }

        Repeater {
            model: AiProviders.providers

            delegate: ColumnLayout {
                id: provCol

                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.padding.small
                    Layout.rightMargin: Tokens.padding.small
                    Layout.topMargin: Tokens.spacing.small

                    MaterialIcon {
                        text: "auto_awesome"
                        color: Colours.palette.m3primary
                        font: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: provCol.modelData.name || qsTr("Provider")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.label.large
                        elide: Text.ElideRight
                    }

                    IconButton {
                        visible: AiProviders.providers.length > 1
                        icon: "delete"
                        type: IconButton.Text
                        onClicked: AiProviders.removeProvider(provCol.modelData.id)
                    }
                }

                TextFieldRow {
                    first: true
                    label: qsTr("Provider Name")
                    subtext: qsTr("Display name shown in model selector")
                    value: provCol.modelData.name
                    placeholderText: "OpenRouter"
                    onEditingFinished: value => {
                        if (value) AiProviders.updateProvider(provCol.modelData.id, { name: value });
                    }
                }

                TextFieldRow {
                    label: qsTr("API Endpoint")
                    subtext: qsTr("Base URL for OpenAI-compatible completions")
                    value: provCol.modelData.baseUrl
                    placeholderText: "https://openrouter.ai/api/v1"
                    onEditingFinished: value => {
                        if (value) AiProviders.updateProvider(provCol.modelData.id, { baseUrl: value });
                    }
                }

                TextFieldRow {
                    last: true
                    label: qsTr("API Key")
                    subtext: qsTr("Bearer token used for API requests")
                    value: provCol.modelData.apiKey || ""
                    placeholderText: "sk-..."
                    onEditingFinished: value => {
                        AiProviders.updateProvider(provCol.modelData.id, { apiKey: value });
                    }
                }

                ConnectedRect {
                    first: true
                    Layout.fillWidth: true
                    implicitHeight: addModelLayout.implicitHeight + Tokens.padding.medium * 2

                    RowLayout {
                        id: addModelLayout
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.medium

                        StyledTextField {
                            id: newModelInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            placeholderText: qsTr("Add model name (e.g. gpt-4o, llama-3.3)...")
                            onAccepted: {
                                var txt = newModelInput.text.trim();
                                if (txt.length > 0) {
                                    var parts = txt.split(",").map(s => s.trim()).filter(s => s.length > 0);
                                    for (var pIdx = 0; pIdx < parts.length; pIdx++) {
                                        AiProviders.addModelToProvider(provCol.modelData.id, parts[pIdx]);
                                    }
                                    newModelInput.text = "";
                                }
                            }
                        }

                        IconButton {
                            icon: "add"
                            type: IconButton.Tonal
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: {
                                var txt = newModelInput.text.trim();
                                if (txt.length > 0) {
                                    var parts = txt.split(",").map(s => s.trim()).filter(s => s.length > 0);
                                    for (var pIdx = 0; pIdx < parts.length; pIdx++) {
                                        AiProviders.addModelToProvider(provCol.modelData.id, parts[pIdx]);
                                    }
                                    newModelInput.text = "";
                                }
                            }
                        }
                    }
                }

                ConnectedRect {
                    Layout.fillWidth: true
                    implicitHeight: modelsContainer.implicitHeight + Tokens.padding.medium * 2

                    ColumnLayout {
                        id: modelsContainer
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        anchors.topMargin: Tokens.padding.medium
                        anchors.bottomMargin: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: qsTr("Configured Models (%1)").arg(provCol.modelData.models ? provCol.modelData.models.length : 0)
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: provCol.modelData.models || []

                                delegate: StyledRect {
                                    id: chipRect
                                    required property string modelData
                                    required property int index

                                    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                                    radius: Tokens.rounding.large
                                    implicitWidth: chipRow.implicitWidth + Tokens.padding.medium * 2
                                    implicitHeight: chipRow.implicitHeight + Tokens.padding.extraSmall * 2

                                    RowLayout {
                                        id: chipRow
                                        x: Tokens.padding.medium
                                        y: Tokens.padding.extraSmall
                                        spacing: Tokens.spacing.extraSmall

                                        MaterialIcon {
                                            text: "smart_toy"
                                            color: Colours.palette.m3primary
                                            font: Tokens.font.icon.small
                                        }

                                        StyledText {
                                            text: chipRect.modelData
                                            color: Colours.palette.m3onSurface
                                            font: Tokens.font.body.small
                                        }

                                        MaterialIcon {
                                            text: "close"
                                            color: Colours.palette.m3onSurfaceVariant
                                            font: Tokens.font.icon.small

                                            StateLayer {
                                                radius: Tokens.rounding.full
                                                onClicked: AiProviders.removeModelFromProvider(provCol.modelData.id, chipRect.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                RowButton {
                    last: true
                    icon: "sync"
                    text: qsTr("Fetch models from endpoint")
                    subtext: qsTr("Auto-discover available models via /models")
                    onClicked: AiProviders.fetchAndSaveModels(provCol.modelData.id)
                }
            }
        }

        RowButton {
            first: true
            last: true
            icon: "add"
            text: qsTr("Add Provider")
            subtext: qsTr("Configure another OpenAI-compatible API endpoint")
            onClicked: AiProviders.addProvider(qsTr("New Provider"), "https://api.openai.com/v1", "", ["gpt-4o-mini"])
        }
    }
}
