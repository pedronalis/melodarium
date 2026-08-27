import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property string currentSection: "all"
    property int currentId: 0

    signal sectionChosen(string section, int id)

    implicitWidth: 220
    color: Theme.mSurfaceVariant
    radius: Theme.radiusM
    border.width: Theme.borderS
    border.color: Theme.mOutline

    function choose(section, id) {
        root.currentSection = section
        root.currentId = id
        root.sectionChosen(section, id)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginS
        spacing: Theme.marginXXS

        // The spec puts collections at the top: they are the differentiator of the product.
        CollectionsSection {
            Layout.fillWidth: true
            currentCollectionId: root.currentSection === "collection" ? root.currentId : 0
            onCollectionChosen: function (id) { root.choose("collection", id) }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.marginS
            Layout.bottomMargin: Theme.marginS
            Layout.preferredHeight: Theme.borderS
            color: Theme.mOutline
        }

        SidebarItem {
            Layout.fillWidth: true
            icon: "microphone"; label: qsTr("Artistas")
            selected: root.currentSection === "artists"
            onClicked: root.choose("artists", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "disc"; label: qsTr("Álbuns")
            selected: root.currentSection === "albums"
            onClicked: root.choose("albums", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "music"; label: qsTr("Gêneros")
            selected: root.currentSection === "genres"
            onClicked: root.choose("genres", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "tags"; label: qsTr("Tags")
            selected: root.currentSection === "tags"
            onClicked: root.choose("tags", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "list"; label: qsTr("Todas as faixas")
            selected: root.currentSection === "all"
            onClicked: root.choose("all", 0)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.marginS
            Layout.bottomMargin: Theme.marginS
            Layout.preferredHeight: Theme.borderS
            color: Theme.mOutline
        }

        SidebarItem {
            Layout.fillWidth: true
            icon: "clock"; label: qsTr("Recentes")
            selected: root.currentSection === "recent"
            onClicked: root.choose("recent", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "star"; label: qsTr("Mais tocadas")
            selected: root.currentSection === "mostPlayed"
            onClicked: root.choose("mostPlayed", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "history"; label: qsTr("Esquecidas")
            selected: root.currentSection === "forgotten"
            onClicked: root.choose("forgotten", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "heart"; label: qsTr("Nunca ouvi")
            selected: root.currentSection === "never"
            onClicked: root.choose("never", 0)
        }

        Item { Layout.fillHeight: true }
    }
}
