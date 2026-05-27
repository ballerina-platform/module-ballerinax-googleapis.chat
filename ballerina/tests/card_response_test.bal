// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/test;

// ═══════════════════════════════════════════════════════════════════════════════
// Card-building scenarios.
//
// These exercise the full Cards V2 widget surface the way a real Chat app does:
// a handler responds to an interaction with a populated card / action response, and
// we assert it round-trips through the dispatcher (build → respond → ResponseFuture
// → serialized response record).
// ═══════════════════════════════════════════════════════════════════════════════

// The rich message card. This is an exact mirror of the card rendered by the
// `googlechat_agent` example app, which was validated live against Google Chat —
// every widget here is confirmed message-valid (header, image, decoratedText with a
// button, decoratedText with a switch, chipList, an overflow-menu button, text/
// selection/date inputs, a bordered grid, a 2-column layout, and a carousel).
//
// Widgets that Google rejects in a *message* (fixedFooter — dialog-only; cardActions
// — Workspace add-on only) are intentionally excluded here and covered separately in
// the dialog/serialization tests below.
isolated function buildRichCard() returns Message {
    Color brandColor = {red: 0.1, green: 0.4, blue: 0.9, alpha: 1.0};
    string logo = "https://www.gstatic.com/images/branding/product/2x/chat_48dp.png";
    Card card = {
        header: {title: "Account", subtitle: "Rich card demo", imageType: CIRCLE},
        sectionDividerStyle: SOLID_DIVIDER,
        sections: [
            {
                header: "Details",
                widgets: [
                    {textParagraph: {text: "A profile rendered from <b>Ballerina</b>."}},
                    {divider: {}},
                    {
                        image: {
                            imageUrl: logo,
                            altText: "Chat logo",
                            onClick: {openLink: {url: "https://workspace.google.com/products/chat/"}}
                        }
                    },
                    // A decoratedText `control` is a oneof: button XOR switchControl —
                    // they must be on separate widgets (verified live: combining them 400s).
                    {
                        decoratedText: {
                            topLabel: "Name",
                            text: "Ada Lovelace",
                            startIcon: {materialIcon: {name: "person", fill: true, weight: 400}, altText: "person"},
                            button: {
                                text: "Edit",
                                color: brandColor,
                                'type: OUTLINED,
                                onClick: {action: {'function: "editProfile", parameters: [{'key: "id", value: "42"}]}}
                            }
                        }
                    },
                    {
                        decoratedText: {
                            topLabel: "Notifications",
                            text: "Email me",
                            switchControl: {name: "notify", value: "on", selected: true, controlType: SWITCH}
                        }
                    },
                    {chipList: {layout: WRAPPED, chips: [{label: "Engineer", icon: {knownIcon: "STAR"}}, {label: "London"}]}},
                    {
                        buttonList: {
                            buttons: [
                                {
                                    text: "More actions",
                                    onClick: {
                                        overflowMenu: {
                                            items: [
                                                {text: "Share", startIcon: {knownIcon: "PERSON"}, onClick: {action: {'function: "share"}}},
                                                {text: "Archive", startIcon: {materialIcon: {name: "archive"}}, onClick: {action: {'function: "archive"}}}
                                            ]
                                        }
                                    }
                                }
                            ]
                        }
                    }
                ]
            },
            {
                header: "Inputs",
                widgets: [
                    {
                        textInput: {
                            name: "fruit",
                            label: "Favorite fruit",
                            'type: SINGLE_LINE,
                            autoCompleteAction: {'function: "fruitAutocomplete"}
                        }
                    },
                    {
                        selectionInput: {
                            name: "role",
                            label: "Role",
                            'type: RADIO_BUTTON,
                            items: [{text: "Admin", value: "admin", selected: true}, {text: "Member", value: "member"}]
                        }
                    },
                    {dateTimePicker: {name: "dob", label: "Birthdate", 'type: DATE_ONLY}}
                ]
            },
            {
                header: "Layout",
                widgets: [
                    {
                        grid: {
                            title: "Gallery",
                            columnCount: 2,
                            borderStyle: {'type: STROKE, strokeColor: brandColor, cornerRadius: 8},
                            items: [
                                {title: "Tile A", image: {imageUri: logo, altText: "a", cropStyle: {'type: SQUARE}}},
                                {title: "Tile B", image: {imageUri: logo, altText: "b", cropStyle: {'type: SQUARE}}}
                            ]
                        }
                    },
                    {
                        columns: {
                            columnItems: [
                                {horizontalSizeStyle: FILL_AVAILABLE_SPACE, widgets: [{textParagraph: {text: "Left"}}]},
                                {horizontalSizeStyle: FILL_AVAILABLE_SPACE, widgets: [{textParagraph: {text: "Right"}}]}
                            ]
                        }
                    }
                ]
            },
            {
                header: "Carousel",
                widgets: [
                    {
                        carousel: {
                            carouselCards: [
                                {
                                    widgets: [{textParagraph: {text: "<b>Slide 1</b>"}}, {image: {imageUrl: logo, altText: "slide 1"}}],
                                    footerWidgets: [
                                        {
                                            buttonList: {
                                                buttons: [
                                                    {
                                                        text: "Open",
                                                        onClick: {openLink: {url: "https://workspace.google.com/products/chat/"}}
                                                    }
                                                ]
                                            }
                                        }
                                    ]
                                },
                                {widgets: [{textParagraph: {text: "<b>Slide 2</b>"}}, {image: {imageUrl: logo, altText: "slide 2"}}]}
                            ]
                        }
                    }
                ]
            }
        ]
    };

    return {
        text: "Here is the rich card demo",
        cardsV2: [{cardId: "richDemo", card: card}],
        // Accessory widgets attach interactive buttons to the bottom of a message.
        accessoryWidgets: [{buttonList: {buttons: [{text: "Quick reply"}]}}]
    };
}

// A dialog body card. Dialogs (unlike messages) support a `fixedFooter` and full
// input forms, so this is where those widgets legitimately belong. Also exercises a
// collapsible section, input validation, and static autocomplete suggestions.
isolated function buildDialogCard() returns Card => {
    header: {title: "Edit contact"},
    sections: [
        {
            header: "Form",
            collapsible: true,
            uncollapsibleWidgetsCount: 1,
            collapseControl: {expandButton: {text: "More"}, collapseButton: {text: "Less"}},
            widgets: [
                {
                    textInput: {
                        name: "email",
                        label: "Email",
                        'type: SINGLE_LINE,
                        validation: {characterLimit: 120, inputType: "EMAIL"},
                        initialSuggestions: {items: [{text: "ada@example.com"}, {text: "grace@example.com"}]}
                    }
                }
            ]
        }
    ],
    fixedFooter: {
        primaryButton: {text: "Save", onClick: {action: {'function: "save"}}},
        secondaryButton: {text: "Cancel", onClick: {action: {'function: "cancel"}}}
    }
};

// An app that renders the rich card when a user clicks a card button.
service class CardBuildingService {
    *ChatService;

    remote function onCardClicked(ChatEvent event, CardClickedCaller caller) returns error? {
        check caller->respond(buildRichCard());
    }

    remote function onWidgetUpdated(ChatEvent event, WidgetUpdatedCaller caller) returns error? {
        Message widgetResponse = {
            actionResponse: {
                'type: UPDATE_WIDGET,
                updatedWidget: {
                    widget: "role",
                    suggestions: {items: [{"text": "Admin", "value": "admin"}]}
                }
            }
        };
        check caller->respond(widgetResponse);
    }
}

@test:Config {}
function testDispatchCardClickReturnsRichCard() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new (testClient);
    CardBuildingService svc = new ();
    check dispatcher.addServiceRef("ChatService", svc);

    map<anydata> response = dispatcher.dispatch(check loadEvent("card_clicked.json"));
    Message message = check response.cloneWithType();

    test:assertEquals(message.text, "Here is the rich card demo");
    CardWithId[] cards = message.cardsV2 ?: [];
    test:assertEquals(cards.length(), 1);
    Section[] sections = cards[0].card?.sections ?: [];
    test:assertEquals(sections.length(), 4);
    // Details section carries the bulk of the widgets.
    test:assertTrue((sections[0].widgets ?: []).length() >= 7);
    // The last section's carousel proves the deep widget tree serialized.
    Widget[] carouselWidgets = sections[3].widgets ?: [];
    test:assertTrue(carouselWidgets[0].carousel?.carouselCards is CarouselCard[]);
    test:assertTrue((message.accessoryWidgets ?: []).length() == 1);
}

@test:Config {}
function testDispatchWidgetUpdatedReturnsUpdatedWidget() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new (testClient);
    CardBuildingService svc = new ();
    check dispatcher.addServiceRef("ChatService", svc);

    map<anydata> response = dispatcher.dispatch(check loadEvent("widget_updated.json"));
    Message message = check response.cloneWithType();
    test:assertEquals(message.actionResponse?.updatedWidget?.widget, "role");
    test:assertTrue(message.actionResponse?.updatedWidget?.suggestions is SelectionItems);
}

// Opening a dialog: the response carries an ActionStatus and a dialog body that uses
// a fixedFooter, a collapsible section, input validation, and static suggestions —
// all valid in a dialog context (where a message wouldn't accept the fixedFooter).
@test:Config {}
function testDialogResponseWithFooterAndForm() returns error? {
    ResponseFuture respFut = new;
    CardClickedCaller caller = new (mockClient, TEST_SPACE, respFut);
    Message dialogResponse = {
        actionResponse: {
            'type: DIALOG,
            dialogAction: {
                actionStatus: {statusCode: "OK", userFacingMessage: "Saved"},
                dialog: {body: buildDialogCard()}
            }
        }
    };
    check caller->respond(dialogResponse);
    map<anydata> result = check awaitPayload(respFut);
    Message message = check result.cloneWithType();

    test:assertEquals(message.actionResponse?.dialogAction?.actionStatus?.statusCode, "OK");
    Card body = message.actionResponse?.dialogAction?.dialog?.body ?: {};
    test:assertTrue(body.fixedFooter?.primaryButton is Button);
    Section[] dialogSections = body.sections ?: [];
    test:assertTrue(dialogSections[0].collapseControl is CollapseControl);
    test:assertTrue((dialogSections[0].widgets ?: [])[0].textInput?.validation is Validation);
}
