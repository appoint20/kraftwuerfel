import Foundation

/*
  Die Reihenfolge, in der die Übungen einer Live-Session drankommen.

  „Überspringen" hieß in der ersten Fassung: der Zeiger springt eine Übung
  weiter, und die übersprungene ist für diese Sitzung verloren. Im Studio ist
  das aber der häufigste Fall überhaupt — die Bank ist besetzt, man macht
  etwas anderes und kommt später zurück. Genau das ging nicht.

  Die Regeln stehen hier und nicht in der Ansicht, weil sie Regeln sind und
  keine Darstellung: Sie lassen sich so einzeln prüfen, ohne eine Live-Session
  zu starten.
*/
public enum LiveQueue {

    /*
      Die Übung an `position` ans Ende schieben.

      Der Zeiger bleibt stehen — dadurch rückt die nächste Übung auf diesen
      Platz und die weggeschobene wartet am Ende.

      Die letzte offene Übung lässt sich nicht wegschieben: Sie stünde sofort
      wieder an derselben Stelle, und der Knopf täte sichtbar nichts.
    */
    public static func deferring(_ order: [Int], at position: Int) -> [Int] {
        guard canDefer(order, at: position) else { return order }
        var next = order
        let moved = next.remove(at: position)
        next.append(moved)
        return next
    }

    public static func canDefer(_ order: [Int], at position: Int) -> Bool {
        order.indices.contains(position) && position < order.count - 1
    }

    /*
      Der erste Satz, der für diese Übung noch aussteht.

      Wer eine angefangene Übung wegschiebt und später zurückkommt, macht
      dort weiter, wo er aufgehört hat — nicht wieder bei Satz 1. Sind alle
      Sätze abgehakt, beginnt sie wieder bei 0; das ist der Fall, in dem der
      Nutzer sie ein zweites Mal machen will.
    */
    public static func firstOpenSet(totalSets: Int, isDone: (Int) -> Bool) -> Int {
        guard totalSets > 0 else { return 0 }
        for setIndex in 0..<totalSets where !isDone(setIndex) {
            return setIndex
        }
        return 0
    }

    /// Was nach der aktuellen Übung noch aussteht — in der Reihenfolge der
    /// Warteschlange, nicht in der des Plans.
    public static func upcoming(_ order: [Int], after position: Int) -> [Int] {
        guard position >= 0, position < order.count else { return [] }
        return Array(order.dropFirst(position + 1))
    }
}
