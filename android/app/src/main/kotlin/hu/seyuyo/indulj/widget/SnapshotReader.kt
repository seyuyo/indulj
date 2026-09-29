package hu.seyuyo.indulj.widget

import java.util.Calendar
import java.util.TimeZone
import org.json.JSONException
import org.json.JSONObject

// A Dart által írt widget-pillanatkép olvasása (séma: lib/widget_bridge/
// snapshot_codec.dart). A Kotlin oldal nem hív API-t és nem számol indulást:
// csak megjelenít. Ami itt „logika", az a megjelenítéshez kell (lásd
// DECISIONS.md): időformázás, elavultság, a már elment sorok elrejtése.

const val SUPPORTED_SNAPSHOT_VERSION = 1

data class WidgetDeparture(
    val route: String,
    val bg: Int,
    val fg: Int,
    val headsign: String,
    val atMs: Long,
    val realtime: Boolean,
    val delayMin: Int?,
)

data class WidgetSnapshot(
    val groupName: String,
    val fetchedAtMs: Long,
    val serverOffsetMs: Long,
    val departures: List<WidgetDeparture>,
    val hasAlerts: Boolean,
    val error: String?,
)

sealed interface WidgetState {
  /** Még nincs pillanatkép (pl. épp most került fel a widget). */
  data object Missing : WidgetState

  /** Ismeretlen verzió vagy sérült adat: „Nyisd meg az appot". */
  data object Unsupported : WidgetState

  data class Ready(val snapshot: WidgetSnapshot) : WidgetState
}

object SnapshotReader {
  fun read(json: String?): WidgetState {
    if (json.isNullOrBlank()) return WidgetState.Missing
    return try {
      val root = JSONObject(json)
      if (root.optInt("v", -1) != SUPPORTED_SNAPSHOT_VERSION) {
        return WidgetState.Unsupported
      }
      WidgetState.Ready(parse(root))
    } catch (e: JSONException) {
      WidgetState.Unsupported
    }
  }

  private fun parse(root: JSONObject): WidgetSnapshot {
    val rows = root.optJSONArray("departures")
    val departures =
        (0 until (rows?.length() ?: 0)).mapNotNull { i ->
          val d = rows!!.optJSONObject(i) ?: return@mapNotNull null
          if (!d.has("atMs")) return@mapNotNull null
          WidgetDeparture(
              route = d.optString("route", "?"),
              bg = parseArgb(d.optNullableString("bg"), 0xFF757575.toInt()),
              fg = parseArgb(d.optNullableString("fg"), 0xFFFFFFFF.toInt()),
              headsign = d.optString("headsign", ""),
              atMs = d.getLong("atMs"),
              realtime = d.optBoolean("realtime", false),
              delayMin = if (d.isNull("delayMin")) null else d.optInt("delayMin"),
          )
        }
    return WidgetSnapshot(
        groupName = root.optString("groupName", ""),
        fetchedAtMs = root.optLong("fetchedAtMs", 0),
        serverOffsetMs = root.optLong("serverOffsetMs", 0),
        departures = departures,
        hasAlerts = root.optBoolean("hasAlerts", false),
        error = root.optNullableString("error"),
    )
  }

  private fun JSONObject.optNullableString(key: String): String? =
      if (isNull(key)) null else optString(key)

  private fun parseArgb(hex: String?, fallback: Int): Int =
      hex?.toLongOrNull(16)?.toInt() ?: fallback
}

/** Megjelenítési szabályok; tiszta függvények, JVM-en tesztelve. */
object WidgetDisplay {
  const val STALE_AFTER_MS = 20 * 60 * 1000L
  private const val DEPARTED_GRACE_MS = 30 * 1000L

  /** 20 percnél régebbi pillanatkép elavult; a még soha nem frissített is. */
  fun isStale(s: WidgetSnapshot, nowMs: Long): Boolean =
      s.fetchedAtMs <= 0 || nowMs - s.fetchedAtMs > STALE_AFTER_MS

  /**
   * A már elment sorokat nem mutatjuk (a telefonóra a szerverhez igazítva),
   * így egy régi pillanatkép sem mutat múltbeli időpontot.
   */
  fun visibleDepartures(s: WidgetSnapshot, nowMs: Long): List<WidgetDeparture> {
    val serverNow = nowMs + s.serverOffsetMs
    return s.departures.filter { it.atMs >= serverNow - DEPARTED_GRACE_MS }
  }

  /** UTC epoch ms → helyi „HH:mm". */
  fun formatTime(utcMs: Long, zone: TimeZone = TimeZone.getDefault()): String {
    val cal = Calendar.getInstance(zone).apply { timeInMillis = utcMs }
    return "%02d:%02d".format(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
  }
}
