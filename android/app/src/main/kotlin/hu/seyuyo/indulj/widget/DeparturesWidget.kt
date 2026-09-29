package hu.seyuyo.indulj.widget

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import hu.seyuyo.indulj.MainActivity
import hu.seyuyo.indulj.R

/**
 * Indulási widget (Jetpack Glance). Csak megjelenít: a pillanatképet a Dart
 * írja `snapshot_<appWidgetId>` kulccsal a home_widget adattárába.
 */
class DeparturesWidget : GlanceAppWidget() {

  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM))

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
    provideContent {
      val prefs = currentState<HomeWidgetGlanceState>().preferences
      val state = SnapshotReader.read(prefs.getString("snapshot_$appWidgetId", null))
      GlanceTheme { Content(context, appWidgetId, state, System.currentTimeMillis()) }
    }
  }

  companion object {
    /** 2×1 */
    val SMALL = DpSize(110.dp, 40.dp)

    /** 4×2 */
    val MEDIUM = DpSize(250.dp, 110.dp)
  }
}

@Composable
private fun Content(context: Context, widgetId: Int, state: WidgetState, nowMs: Long) {
  val openApp = actionStartActivity<MainActivity>(context)
  val refresh = actionRunCallback<RefreshAction>(actionParametersOf(RefreshAction.WIDGET_ID to widgetId))
  val medium = LocalSize.current.height >= DeparturesWidget.MEDIUM.height

  Box(
      modifier =
          GlanceModifier.fillMaxSize()
              .background(GlanceTheme.colors.widgetBackground)
              .cornerRadius(16.dp)
              .padding(horizontal = 12.dp, vertical = 8.dp)
              .clickable(openApp),
  ) {
    when (state) {
      WidgetState.Missing -> Message("Betöltés…", refresh)
      WidgetState.Unsupported -> Message("Nyisd meg az appot", null)
      is WidgetState.Ready -> Ready(state.snapshot, nowMs, medium, refresh)
    }
  }
}

@Composable
private fun Ready(
    s: WidgetSnapshot,
    nowMs: Long,
    medium: Boolean,
    refresh: androidx.glance.action.Action,
) {
  when (s.error) {
    "noGroup" -> return Message("Válassz csoportot az appban", null)
    "unauthorized" -> return Message("Hiba – nyisd meg az appot", null)
  }
  val stale = WidgetDisplay.isStale(s, nowMs)
  val rows = WidgetDisplay.visibleDepartures(s, nowMs)
  val dim = GlanceTheme.colors.onSurfaceVariant

  Column(modifier = GlanceModifier.fillMaxSize()) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
      Text(
          s.groupName,
          maxLines = 1,
          style = TextStyle(fontWeight = FontWeight.Bold, color = GlanceTheme.colors.onSurface),
          modifier = GlanceModifier.defaultWeight(),
      )
      if (s.hasAlerts) Icon(R.drawable.ic_widget_alert, GlanceTheme.colors.error)
      if (s.error != null) Icon(R.drawable.ic_widget_offline, GlanceTheme.colors.error)
      if (!medium) {
        Spacer(GlanceModifier.width(4.dp))
        Icon(R.drawable.ic_widget_refresh, dim, GlanceModifier.clickable(refresh))
      }
    }

    if (rows.isEmpty()) {
      Text("Nincs indulás 60 percen belül", style = TextStyle(color = dim, fontSize = 13.sp))
    } else {
      for (d in rows.take(if (medium) 4 else 1)) DepartureRow(d, stale)
    }

    if (medium) {
      Spacer(GlanceModifier.defaultWeight())
      Row(
          modifier = GlanceModifier.fillMaxWidth(),
          verticalAlignment = Alignment.CenterVertically,
      ) {
        val updated =
            if (s.fetchedAtMs > 0) WidgetDisplay.formatTime(s.fetchedAtMs) else "–"
        Text(
            if (stale) "elavult · frissítve $updated" else "frissítve $updated",
            style = TextStyle(color = dim, fontSize = 12.sp),
            modifier = GlanceModifier.defaultWeight(),
        )
        Icon(R.drawable.ic_widget_refresh, dim, GlanceModifier.clickable(refresh))
      }
    }
  }
}

@Composable
private fun DepartureRow(d: WidgetDeparture, stale: Boolean) {
  val gray = Color(0xFF9E9E9E)
  Row(
      modifier = GlanceModifier.fillMaxWidth().padding(vertical = 2.dp),
      verticalAlignment = Alignment.CenterVertically,
  ) {
    Box(
        modifier =
            GlanceModifier.background(ColorProvider(if (stale) gray else Color(d.bg)))
                .cornerRadius(4.dp)
                .padding(horizontal = 6.dp, vertical = 1.dp),
    ) {
      Text(
          d.route,
          maxLines = 1,
          style =
              TextStyle(
                  fontWeight = FontWeight.Bold,
                  fontSize = 13.sp,
                  color = ColorProvider(if (stale) Color.White else Color(d.fg)),
              ),
      )
    }
    Spacer(GlanceModifier.width(8.dp))
    val text = if (stale) GlanceTheme.colors.onSurfaceVariant else GlanceTheme.colors.onSurface
    Text(
        d.headsign,
        maxLines = 1,
        style = TextStyle(color = text, fontSize = 13.sp),
        modifier = GlanceModifier.defaultWeight(),
    )
    d.delayMin?.let {
      Text("+$it ", style = TextStyle(color = GlanceTheme.colors.error, fontSize = 12.sp))
    }
    Text(
        WidgetDisplay.formatTime(d.atMs),
        style = TextStyle(fontWeight = FontWeight.Bold, color = text, fontSize = 14.sp),
    )
  }
}

@Composable
private fun Message(text: String, refresh: androidx.glance.action.Action?) {
  Row(
      modifier = GlanceModifier.fillMaxSize(),
      verticalAlignment = Alignment.CenterVertically,
  ) {
    Text(
        text,
        style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 13.sp),
        modifier = GlanceModifier.defaultWeight(),
    )
    if (refresh != null) {
      Icon(R.drawable.ic_widget_refresh, GlanceTheme.colors.onSurfaceVariant, GlanceModifier.clickable(refresh))
    }
  }
}

@Composable
private fun Icon(
    res: Int,
    tint: ColorProvider,
    modifier: GlanceModifier = GlanceModifier,
) {
  Image(
      provider = ImageProvider(res),
      contentDescription = null,
      colorFilter = ColorFilter.tint(tint),
      modifier = modifier.size(20.dp),
  )
}

/** ⟳: a Dart háttér-callbackje frissíti ezt az egy widgetet. */
class RefreshAction : ActionCallback {
  override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
    val id = parameters[WIDGET_ID] ?: return
    HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("indulj://refresh?id=$id")).send()
  }

  companion object {
    val WIDGET_ID = ActionParameters.Key<Int>("widgetId")
  }
}
