import SwiftUI
import WidgetKit

/*
  Das fehlende Ziel.

  Eine Live Activity wird nicht von der App gezeichnet, sondern von einer
  Widget-Erweiterung. Ohne dieses Bündel nimmt ActivityKit `Activity.request`
  zwar an, findet aber keine `ActivityConfiguration` für den Typ — und der
  Sperrbildschirm bleibt leer, ohne dass irgendwo ein Fehler auftaucht.

  Genau das war der Grund, warum die Karte nie erschien.
*/
@main
struct KraftwuerfelWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
