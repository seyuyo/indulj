package hu.seyuyo.indulj.widget

import java.io.File
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A test/fixtures/snapshots fájlokat a Dart codec-teszt írja; ugyanezeket
 * olvassuk itt, így a két oldal szerződését egy fájlkészlet védi.
 */
class SnapshotReaderTest {
  private val fixtures = File("../../test/fixtures/snapshots")

  private fun read(name: String): WidgetState =
      SnapshotReader.read(File(fixtures, "$name.json").readText(Charsets.UTF_8))

  private fun ready(name: String): WidgetSnapshot =
      (read(name) as? WidgetState.Ready)?.snapshot
          ?: throw AssertionError("$name: expected Ready, got ${read(name)}")

  private val budapest = TimeZone.getTimeZone("Europe/Budapest")
  private val t0 = 1790683200000L // 2026-09-29 14:00 Budapest
  private val minute = 60_000L

  @Test
  fun `normal snapshot has every field`() {
    val s = ready("normal")
    assertEquals("Oktogon", s.groupName)
    assertEquals(t0 + 1200, s.fetchedAtMs)
    assertEquals(-1200L, s.serverOffsetMs)
    assertFalse(s.hasAlerts)
    assertNull(s.error)
    assertEquals(2, s.departures.size)

    val first = s.departures[0]
    assertEquals("4", first.route)
    assertEquals(0xFFFFD800.toInt(), first.bg)
    assertEquals(0xFF000000.toInt(), first.fg)
    assertEquals("Széll Kálmán tér M", first.headsign)
    assertEquals(t0 + 3 * minute, first.atMs)
    assertTrue(first.realtime)
    assertEquals(2, first.delayMin)
    assertNull(s.departures[1].delayMin)
  }

  @Test
  fun `empty list is ready with no departures`() {
    val s = ready("empty")
    assertTrue(s.departures.isEmpty())
    assertNull(s.error)
  }

  @Test
  fun `network error keeps the previous rows`() {
    val s = ready("error_network")
    assertEquals("network", s.error)
    assertEquals(2, s.departures.size)
    assertEquals(t0 + 1200, s.fetchedAtMs)
  }

  @Test
  fun `unauthorized without data was never fetched`() {
    val s = ready("error_unauthorized")
    assertEquals("unauthorized", s.error)
    assertEquals(0L, s.fetchedAtMs)
    assertTrue(WidgetDisplay.isStale(s, t0))
  }

  @Test
  fun `no group state`() {
    assertEquals("noGroup", ready("no_group").error)
  }

  @Test
  fun `unknown version does not crash`() {
    assertEquals(WidgetState.Unsupported, read("future_version"))
  }

  @Test
  fun `missing fields get defaults`() {
    val s = ready("missing_fields")
    val d = s.departures.single()
    assertEquals("4", d.route)
    assertEquals("", d.headsign)
    assertEquals(0xFF757575.toInt(), d.bg)
    assertEquals(0xFFFFFFFF.toInt(), d.fg)
    assertFalse(d.realtime)
    assertNull(d.delayMin)
    assertFalse(s.hasAlerts)
    assertNull(s.error)
  }

  @Test
  fun `missing, blank and garbage input`() {
    assertEquals(WidgetState.Missing, SnapshotReader.read(null))
    assertEquals(WidgetState.Missing, SnapshotReader.read(""))
    assertEquals(WidgetState.Unsupported, SnapshotReader.read("nem json"))
    assertEquals(WidgetState.Unsupported, SnapshotReader.read("[1,2]"))
    assertEquals(WidgetState.Unsupported, SnapshotReader.read("{}"))
  }

  @Test
  fun `stale after 20 minutes`() {
    val s = ready("normal")
    assertFalse(WidgetDisplay.isStale(s, s.fetchedAtMs + 20 * minute))
    assertTrue(WidgetDisplay.isStale(s, s.fetchedAtMs + 20 * minute + 1))
  }

  @Test
  fun `departed rows are hidden using the server offset`() {
    val s = ready("normal") // 14:03 és 14:05, offset −1,2 mp
    assertEquals(2, WidgetDisplay.visibleDepartures(s, t0).size)
    // 14:03:30 szerveridő: a 14:03-as még 30 mp-ig látszik
    assertEquals(2, WidgetDisplay.visibleDepartures(s, t0 + 3 * minute + 30_000 + 1200).size)
    assertEquals(1, WidgetDisplay.visibleDepartures(s, t0 + 3 * minute + 31_000 + 1200).size)
    assertEquals(0, WidgetDisplay.visibleDepartures(s, t0 + 60 * minute).size)
  }

  @Test
  fun `local time formatting, including DST and midnight`() {
    assertEquals("14:03", WidgetDisplay.formatTime(t0 + 3 * minute, budapest))
    // 2026-03-29 00:55 UTC = 01:55 CET, 01:05 UTC = 03:05 CEST
    assertEquals("01:55", WidgetDisplay.formatTime(1774745700000L, budapest))
    assertEquals("03:05", WidgetDisplay.formatTime(1774746300000L, budapest))
    // 2026-09-29 22:10 UTC = 00:10 másnap
    assertEquals("00:10", WidgetDisplay.formatTime(1790719800000L, budapest))
  }

  @Test
  fun `first row counts down, then says indul, stale shows time`() {
    val s = ready("normal") // első: 14:03 szerveridő, offset −1,2 mp
    val first = s.departures[0]
    // telefon 14:00:01,2 → szerver 14:00:00 → 3 perc van hátra
    assertEquals(
        RowTime.Countdown(3 * minute),
        WidgetDisplay.firstRowTime(first, s, t0 + 1200),
    )
    assertEquals(RowTime.Departing, WidgetDisplay.firstRowTime(first, s, t0 + 3 * minute + 1200))
    assertEquals(
        RowTime.Departing,
        WidgetDisplay.firstRowTime(first, s, t0 + 3 * minute + 1200 + 29_000),
    )
    // 20 perc után elavult: nem számol vissza
    assertTrue(
        WidgetDisplay.firstRowTime(first, s, s.fetchedAtMs + 21 * minute) is RowTime.Absolute)
  }

  @Test
  fun `departures an hour or more away show the time`() {
    val s = ready("normal")
    val far = s.departures[0].copy(atMs = t0 + 90 * minute)
    val time = WidgetDisplay.firstRowTime(far, s, t0 + 1200)
    assertTrue(time is RowTime.Absolute)
  }

  @Test
  fun `empty message distinguishes no departures from old data`() {
    val empty = ready("empty")
    assertEquals("Nincs indulás 60 percen belül", WidgetDisplay.emptyMessage(empty, t0))
    // Minden sor elment, és az adat elavult: nem „nincs indulás".
    val normal = ready("normal")
    assertEquals(
        "Nincs friss adat – koppints a ⟳-ra",
        WidgetDisplay.emptyMessage(normal, normal.fetchedAtMs + 25 * minute),
    )
    val offline = ready("error_network")
    assertEquals(
        "Nincs friss adat – koppints a ⟳-ra",
        WidgetDisplay.emptyMessage(offline, offline.fetchedAtMs + 10 * minute),
    )
  }
}
