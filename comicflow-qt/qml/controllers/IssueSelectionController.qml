import QtQuick

Item {
    id: controller
    visible: false
    width: 0
    height: 0

    property var selectedIds: ({})

    function isSelected(id) {
        return selectedIds[String(id)] === true
    }

    function setSelected(id, checked) {
        const key = String(id)
        const next = Object.assign({}, selectedIds)
        if (checked) {
            next[key] = true
        } else {
            delete next[key]
        }
        selectedIds = next
    }

    function clearSelection() {
        selectedIds = ({})
    }
}
