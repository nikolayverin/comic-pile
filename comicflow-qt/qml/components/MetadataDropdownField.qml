import QtQuick
import QtQuick.Controls

FocusScope {
    id: root

    PopupStyle { id: popupStyle }
    PopupMenuStyle { id: popupMenuStyle }

    property var model: []
    property int currentIndex: -1
    property alias text: inputField.text
    property alias editText: inputField.text
    property alias cursorPosition: inputField.cursorPosition
    readonly property bool popupVisible: dropdownPopup.visible
    readonly property string currentText: String(inputField.text || "")
    property string filterText: String(inputField.text || "")

    property int fieldFontPixelSize: popupStyle.dialogBodyFontSize
    property int fieldRadius: popupStyle.fieldRadius
    property int fieldPadX: popupStyle.fieldPadX
    property int popupYOffset: popupMenuStyle.verticalOffset
    property int popupMinBodyHeight: 40
    property int popupMaxBodyHeight: 280
    readonly property int popupRowHeight: popupMenuStyle.rowHeight
    property int popupWidthOverride: 0
    property int indicatorHitBoxSize: 0
    readonly property int indicatorGlyphWidth: 11
    readonly property int indicatorGlyphHeight: 5

    property alias inputMethodHints: inputField.inputMethodHints
    property alias validator: inputField.validator
    property alias maximumLength: inputField.maximumLength

    signal accepted()
    signal activated(int index)

    implicitWidth: 120
    implicitHeight: popupStyle.fieldHeight

    property bool syncingInternally: false

    function normalizedOptions() {
        return Array.isArray(model) ? model : []
    }

    function optionTextAt(index) {
        const options = normalizedOptions()
        if (index < 0 || index >= options.length) return ""
        return String(options[index] || "")
    }

    function indexOfOption(value) {
        const normalizedValue = String(value || "").trim()
        const options = normalizedOptions()
        for (let i = 0; i < options.length; i += 1) {
            if (String(options[i] || "").trim() === normalizedValue) {
                return i
            }
        }
        return -1
    }

    function filteredOptions() {
        const options = normalizedOptions()
        const query = String(filterText || "").trim().toLowerCase()
        if (query.length < 1) return options
        return options.filter(function(item) {
            return String(item || "").toLowerCase().indexOf(query) === 0
        })
    }

    function popupMenuItems() {
        const options = filteredOptions()
        return options.map(function(item) {
            const text = String(item || "")
            return {
                text: text,
                action: text,
                enabled: true,
                highlighted: text === String(root.currentText || "")
            }
        })
    }

    function openPopup() {
        inputField.forceActiveFocus()
        dropdownPopup.openBelowItemCentered(root, root)
    }

    function focusInput() {
        inputField.forceActiveFocus()
        inputField.cursorPosition = String(inputField.text || "").length
    }

    function closePopup() {
        dropdownPopup.close()
    }

    function togglePopup() {
        if (dropdownPopup.visible) closePopup()
        else openPopup()
    }

    function selectAll() {
        inputField.selectAll()
    }

    function copy() {
        inputField.copy()
    }

    function deselect() {
        inputField.deselect()
    }

    function syncIndexFromText() {
        if (syncingInternally) return
        syncingInternally = true
        currentIndex = indexOfOption(inputField.text)
        syncingInternally = false
    }

    onCurrentIndexChanged: {
        if (syncingInternally) return
        if (currentIndex < 0) return
        const selectedText = optionTextAt(currentIndex)
        syncingInternally = true
        inputField.text = selectedText
        syncingInternally = false
    }

    onModelChanged: syncIndexFromText()

    PopupFieldBackground {
        anchors.fill: parent
        cornerRadius: root.fieldRadius
        fillColor: popupStyle.fieldFillColor
    }

    TextField {
        id: inputField
        anchors.fill: parent
        leftPadding: root.fieldPadX
        rightPadding: root.fieldPadX + 24
        font.pixelSize: root.fieldFontPixelSize
        color: popupStyle.textColor
        verticalAlignment: TextInput.AlignVCenter
        placeholderText: ""
        background: null
        selectByMouse: true

        onTextChanged: {
            root.filterText = String(text || "")
            root.syncIndexFromText()
        }

        onAccepted: {
            root.accepted()
            dropdownPopup.close()
        }

        Keys.onDownPressed: function(event) {
            root.openPopup()
            event.accepted = true
        }

        Keys.onEscapePressed: function(event) {
            if (dropdownPopup.visible) {
                dropdownPopup.close()
                event.accepted = true
            }
        }
    }

    Item {
        id: indicatorHitBox
        width: root.indicatorHitBoxSize > 0 ? root.indicatorHitBoxSize : root.indicatorGlyphWidth
        height: root.indicatorHitBoxSize > 0 ? root.indicatorHitBoxSize : root.indicatorGlyphHeight
        anchors.right: parent.right
        anchors.rightMargin: Math.max(0, 12 - ((width - root.indicatorGlyphWidth) / 2))
        anchors.verticalCenter: parent.verticalCenter

        Canvas {
            id: indicatorGlyph
            width: root.indicatorGlyphWidth
            height: root.indicatorGlyphHeight
            anchors.centerIn: parent
            transformOrigin: Item.Center
            rotation: dropdownPopup.visible ? 180 : 0

            Behavior on rotation {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            contextType: "2d"
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = popupStyle.comboIndicatorColor
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(width, 0)
                ctx.lineTo(width / 2, height)
                ctx.closePath()
                ctx.fill()
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePopup()
        }
    }

    ContextMenuPopup {
        id: dropdownPopup
        uiFontFamily: popupMenuStyle.uiFontFamily
        uiFontPixelSize: popupMenuStyle.uiFontPixelSize
        backgroundColor: popupMenuStyle.backgroundColor
        hoverColor: popupMenuStyle.hoverColor
        textColor: popupMenuStyle.textColor
        disabledTextColor: popupMenuStyle.disabledTextColor
        rowHeight: popupMenuStyle.rowHeight
        bodyRadius: popupMenuStyle.bodyRadius
        arrowWidth: popupMenuStyle.arrowWidth
        arrowHeight: popupMenuStyle.arrowHeight
        verticalOffset: root.popupYOffset
        revealOffsetYHidden: popupMenuStyle.revealOffsetYHidden
        minWidth: root.popupWidthOverride
        closeOnFocusLoss: false
        minBodyHeight: root.popupMinBodyHeight
        maxBodyHeight: root.popupMaxBodyHeight
        menuItems: root.popupMenuItems()

        onVisibleChanged: {
            if (visible) {
                root.filterText = ""
            }
        }

        onItemTriggered: function(index, action) {
            const selectedText = String(action || "")
            const idx = root.indexOfOption(selectedText)
            root.syncingInternally = true
            root.text = selectedText
            root.currentIndex = idx
            root.syncingInternally = false
            root.activated(idx)
            dropdownPopup.close()
        }
    }
}
