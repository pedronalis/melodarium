import QtQuick

QtObject {
    id: root

    property int limit: 5
    property var notices: []
    readonly property int count: root.notices.length
    readonly property var current: root.count > 0 ? root.notices[0] : null

    function push(notice) {
        if (notice === undefined || notice === null || notice.key === undefined)
            return
        const next = root.notices.slice()
        let existing = -1
        for (let i = 0; i < next.length; ++i) {
            if (next[i].key === notice.key) {
                existing = i
                break
            }
        }
        if (existing >= 0)
            next[existing] = notice
        else
            next.push(notice)
        root.notices = next.length > root.limit ? next.slice(next.length - root.limit) : next
    }

    function clear(key) {
        root.notices = root.notices.filter(function(notice) { return notice.key !== key })
    }

    function clearAll() {
        root.notices = []
    }

    function dismissCurrent() {
        if (root.count > 0)
            root.notices = root.notices.slice(1)
    }

    function retryCurrent() {
        if (root.current === null || root.current.action === undefined
            || root.current.action === null)
            return
        const action = root.current.action
        root.dismissCurrent()
        action()
    }
}
