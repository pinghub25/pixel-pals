package com.matsavin.pixelpals

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.os.LocaleListCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.math.abs
import kotlin.math.sin

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        Pals.load(this)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme(background = Ink, surface = Ink)) {
                // Surface sets white text; the insets keep content clear of the status and navigation bars.
                Surface(Modifier.fillMaxSize(), color = Ink, contentColor = Color.White) {
                    Box(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) { App() }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (Pals.profile.value != null) Pals.refresh(this)
        // Back from Settings: start the pill once the overlay permission is granted.
        if (PetStore.flag(this, PetStore.OVERLAY) && IslandService.canDraw(this)) IslandService.start(this)
    }
}

private val Ink = Color(0xFF0E0B1C)
private val CardColor = Color(0x14FFFFFF)

@Composable
private fun App() {
    val profile by Pals.profile.collectAsState()
    var editing by remember { mutableStateOf(false) }
    var messages by remember { mutableStateOf(false) }
    val p = profile
    when {
        p == null -> ProfileForm(stringResource(R.string.adopt_title), stringResource(R.string.adopt), null) { Pals.save(it.first, it.second) }
        editing -> {
            BackHandler { editing = false }
            ProfileForm(stringResource(R.string.edit_title), stringResource(R.string.save), p) { (c, updated) ->
                Pals.save(c, updated.copy(accessory = p.accessory))
                editing = false
            }
        }
        messages -> {
            BackHandler { messages = false }
            MyMessages(p) { messages = false }
        }
        else -> Home(p, onEdit = { editing = true }, onMessages = { messages = true })
    }
}

/** The animated pal: bob, blink every few seconds, a happy wiggle every six, hops when reacting. */
@Composable
private fun AnimatedPet(kind: PetKind, accessory: Accessory?, emotion: PetEmotion, reactionAt: Long, modifier: Modifier) {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            now = System.currentTimeMillis()
            delay(83)
        }
    }
    Canvas(modifier) {
        val t = now / 1000.0
        val reacting = now - reactionAt < 1600
        val wiggle = emotion != PetEmotion.SAD && (t % 6.0) < 0.7
        val frame = when {
            reacting || wiggle -> 2
            (t % 3.4) < 0.18 -> 1
            else -> emotion.frame
        }
        val px = size.minDimension / 16
        val hop = when {
            reacting -> abs(sin(t * 9)) * 3
            wiggle -> abs(sin(t * 9)) * 2
            emotion == PetEmotion.SAD -> 0.0
            sin(t * 2.4) > 0 -> 1.0
            else -> 0.0
        }
        rotate(0f) {
            drawIntoCanvas {
                Sprites.draw(it.nativeCanvas, kind, frame, accessory, (size.width - px * 16) / 2, (size.height - px * 16) / 2 - hop.toFloat() * px, px * 16)
            }
        }
    }
}

@Composable
private fun StaticPet(kind: PetKind, frame: Int, accessory: Accessory?, modifier: Modifier) {
    Canvas(modifier) { drawIntoCanvas { Sprites.draw(it.nativeCanvas, kind, frame, accessory, 0f, 0f, size.minDimension) } }
}

@Composable
private fun Card(content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(CardColor).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) { content() }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Home(p: Profile, onEdit: () -> Unit, onMessages: () -> Unit) {
    val context = LocalContext.current
    val haptics = LocalHapticFeedback.current
    val care by Pals.care.collectAsState()
    val reaction by Pals.reaction.collectAsState()
    val revision by Pals.revision.collectAsState()
    val accent = Color(p.pet.accent)
    val now = care.at()

    Scaffold(
        containerColor = Ink,
        contentWindowInsets = WindowInsets(0),
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.app_name), fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = onEdit) { Icon(Icons.Outlined.Edit, stringResource(R.string.edit), tint = accent) }
                },
                windowInsets = WindowInsets(0),
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Ink),
            )
        },
    ) { bars ->
    Column(
        Modifier.fillMaxSize().padding(bars).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {

        // Pet stage
        Box(
            Modifier.fillMaxWidth().height(250.dp).clip(RoundedCornerShape(28.dp))
                .background(Brush.verticalGradient(listOf(accent.copy(alpha = 0.35f), accent.copy(alpha = 0.04f))))
                .clickable {
                    haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    Pals.perform(context, PetAction.PAT)
                },
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                AnimatedPet(p.pet, p.accessory, now.emotion, reaction?.second ?: 0, Modifier.size(170.dp))
                Text(stringResource(R.string.tap_to_say_hi, p.name), fontSize = 12.sp, color = Color.Gray)
            }
        }

        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(p.name, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Text("${p.sign.symbol} ${stringResource(p.sign.nameRes)} · ${stringResource(p.sign.elementRes)}", color = accent)
            Text(stringResource(now.emotion.lineRes, p.name), color = Color.Gray, fontSize = 14.sp)
            Text("🔥 ${stringResource(R.string.streak, now.streak)}   ❤️ ${now.love}", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }

        Card {
            CareBar(stringResource(R.string.food), now.food, Color(0xFFFF9F0A))
            CareBar(stringResource(R.string.fun_), now.fun_, Color(0xFF0A84FF))
            CareBar(stringResource(R.string.energy), now.energy, Color(0xFFBF5AF2))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                listOf(
                    Triple("🍎", R.string.feed, PetAction.FEED),
                    Triple("⚽", R.string.play, PetAction.PLAY),
                    Triple("💤", R.string.nap, PetAction.NAP),
                ).forEach { (emoji, label, action) ->
                    OutlinedButton(
                        onClick = {
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            Pals.perform(context, action)
                        },
                        modifier = Modifier.weight(1f),
                        border = BorderStroke(1.dp, accent.copy(alpha = 0.5f)),
                        contentPadding = PaddingValues(horizontal = 4.dp, vertical = 8.dp),
                    ) {
                        // One line even for longer Russian labels ("Покормить").
                        Text("$emoji ${stringResource(label)}", color = accent, fontSize = 12.sp, maxLines = 1, softWrap = false)
                    }
                }
            }
        }

        Accessories(p, now.love)

        Card {
            Text("${stringResource(PetStore.dailyContent(context).resolved(LocalDate.now(), PetStore.customMessages(context).isNotEmpty()).titleRes)} · ${Messages.shortDate(context)}", fontSize = 12.sp, color = Color.Gray)
            // revision is read so the message recomposes after a language or content change.
            Text(if (revision >= 0) Messages.today(context, p) else "", fontSize = 19.sp, fontWeight = FontWeight.SemiBold)
            TextButton(onClick = onMessages) { Text("＋ ${stringResource(R.string.my_messages)}", color = accent) }
        }

        SettingsCard(p, accent)
    }
    }
}

@Composable
private fun CareBar(label: String, value: Double, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.width(80.dp), fontSize = 14.sp)
        LinearProgressIndicator(
            progress = { value.toFloat() },
            modifier = Modifier.weight(1f).height(6.dp).clip(RoundedCornerShape(3.dp)),
            color = if (value < PetCare.LOW) Color(0xFFFF453A) else color,
            trackColor = Color(0x22FFFFFF),
        )
    }
}

@Composable
private fun Accessories(p: Profile, love: Int) {
    val context = LocalContext.current
    val accent = Color(p.pet.accent)
    Card {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.accessories), fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            Text("❤️ $love", color = Color(0xFFFF6B8B), fontWeight = FontWeight.SemiBold)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Accessory.entries.forEach { a ->
                val unlocked = love >= a.hearts
                val worn = p.accessory == a
                Column(
                    Modifier.weight(1f).clip(RoundedCornerShape(14.dp))
                        .background(if (worn) accent.copy(alpha = 0.25f) else Color(0x0AFFFFFF))
                        .border(2.dp, if (worn) accent else Color.Transparent, RoundedCornerShape(14.dp))
                        .clickable(enabled = unlocked) { Pals.wear(context, if (worn) null else a) }
                        .padding(vertical = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        StaticPet(p.pet, 0, a, Modifier.size(46.dp).alpha(if (unlocked) 1f else 0.25f))
                        if (!unlocked) Text("🔒")
                    }
                    Text(if (unlocked) stringResource(a.titleRes) else "${a.hearts} ♥", fontSize = 11.sp, maxLines = 1)
                }
            }
        }
        Accessory.entries.firstOrNull { it.hearts > love }?.let { next ->
            Text(stringResource(R.string.unlocks_at, stringResource(next.titleRes), next.hearts), fontSize = 12.sp, color = Color.Gray)
        }
    }
}

@Composable
private fun SettingsCard(p: Profile, accent: Color) {
    val context = LocalContext.current
    val activity = context as? AppCompatActivity
    var overlay by remember { mutableStateOf(PetStore.flag(context, PetStore.OVERLAY)) }
    var appAware by remember { mutableStateOf(PetStore.flag(context, PetStore.APP_AWARE)) }
    var reminder by remember { mutableStateOf(PetStore.flag(context, PetStore.REMINDER)) }
    var careAlerts by remember { mutableStateOf(PetStore.flag(context, PetStore.CARE_ALERTS)) }
    var minutes by remember { mutableStateOf(PetStore.reminderMinutes(context)) }
    var content by remember { mutableStateOf(PetStore.dailyContent(context)) }
    var sent by remember { mutableStateOf(false) }
    var pickingTime by remember { mutableStateOf(false) }
    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted && PetStore.flag(context, PetStore.OVERLAY)) IslandService.start(context) // shows its notification
    }

    fun askNotifications() {
        if (Build.VERSION.SDK_INT >= 33) notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    Card {
        Toggle(stringResource(R.string.show_around_camera, p.name), overlay, accent, stringResource(R.string.show_around_camera_hint)) { on ->
            overlay = on
            PetStore.setFlag(context, PetStore.OVERLAY, on)
            if (on) askNotifications() // the Peek and Pet buttons live in the pal's notification
            if (!on) IslandService.stop(context)
            else if (IslandService.canDraw(context)) IslandService.start(context)
            else context.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}")))
        }
        if (overlay) {
            val tapping by TapService.connected.collectAsState()
            // Accessibility can only be switched in system Settings; the switch reflects it.
            Toggle(stringResource(R.string.tap_pal, p.name), tapping, accent, stringResource(R.string.tap_pal_hint)) {
                context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            }
            Toggle(stringResource(R.string.calm_on_home), appAware, accent, stringResource(R.string.calm_on_home_hint)) { on ->
                appAware = on
                PetStore.setFlag(context, PetStore.APP_AWARE, on)
                if (on && !IslandService.hasUsageAccess(context)) context.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
            }
        }

        Choice(
            stringResource(R.string.language),
            listOf(R.string.language_system to "", R.string.language_en to "en", R.string.language_ru to "ru"),
            AppCompatDelegate.getApplicationLocales().toLanguageTags(),
        ) { tag ->
            AppCompatDelegate.setApplicationLocales(if (tag.isEmpty()) LocaleListCompat.getEmptyLocaleList() else LocaleListCompat.forLanguageTags(tag))
            // The pill and widget run outside the activity; restart them in the new language.
            if (PetStore.flag(context, PetStore.OVERLAY)) {
                IslandService.stop(context)
                IslandService.start(context)
            }
            Pals.settingsChanged(context)
            activity?.recreate()
        }

        Choice(stringResource(R.string.daily_content), DailyContent.entries.map { it.titleRes to it.name }, content.name) { name ->
            content = DailyContent.valueOf(name)
            PetStore.setDailyContent(context, content)
            Pals.settingsChanged(context)
        }

        Toggle(stringResource(R.string.daily_notification), reminder, accent) { on ->
            reminder = on
            PetStore.setFlag(context, PetStore.REMINDER, on)
            if (on) askNotifications()
            Reminders.schedule(context)
        }
        if (reminder) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.deliver_at), Modifier.weight(1f))
                TextButton(onClick = { pickingTime = true }) { Text("%02d:%02d".format(minutes / 60, minutes % 60), color = accent) }
            }
        }
        Toggle(stringResource(R.string.care_alerts, p.name), careAlerts, accent) { on ->
            careAlerts = on
            PetStore.setFlag(context, PetStore.CARE_ALERTS, on)
            if (on) askNotifications()
            Reminders.scheduleCareAlert(context)
        }
        if (pickingTime) {
            TimeDialog(minutes, accent, onDismiss = { pickingTime = false }) { picked ->
                minutes = picked
                PetStore.setReminderMinutes(context, picked)
                Reminders.schedule(context)
                pickingTime = false
            }
        }
        OutlinedButton(
            onClick = {
                askNotifications()
                Reminders.sendNow(context)
                sent = true
            },
            modifier = Modifier.fillMaxWidth(),
            border = BorderStroke(1.dp, accent.copy(alpha = 0.5f)),
        ) { Text(stringResource(if (sent) R.string.sent else R.string.send_now), color = accent) }
    }
}

@Composable
private fun Toggle(label: String, checked: Boolean, accent: Color, hint: String? = null, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f).padding(end = 12.dp)) {
            Text(label, fontSize = 15.sp)
            if (hint != null) Text(hint, fontSize = 12.sp, color = Color.Gray, lineHeight = 15.sp)
        }
        Switch(checked, onChange, colors = SwitchDefaults.colors(checkedTrackColor = accent, checkedThumbColor = Color.Black))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TimeDialog(minutes: Int, accent: Color, onDismiss: () -> Unit, onPick: (Int) -> Unit) {
    val state = rememberTimePickerState(minutes / 60, minutes % 60, is24Hour = true)
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = { onPick(state.hour * 60 + state.minute) }) { Text("OK", color = accent) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(android.R.string.cancel)) } },
        text = { TimePicker(state) },
    )
}

@Composable
private fun Choice(label: String, options: List<Pair<Int, String>>, selected: String, onPick: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), fontSize = 15.sp)
        Box {
            TextButton(onClick = { open = true }) {
                Text(stringResource(options.firstOrNull { it.second == selected }?.first ?: options.first().first) + " ▾")
            }
            DropdownMenu(open, { open = false }) {
                options.forEach { (res, value) ->
                    DropdownMenuItem(text = { Text(stringResource(res)) }, onClick = {
                        open = false
                        onPick(value)
                    })
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProfileForm(title: String, button: String, initial: Profile?, onSave: (Pair<android.content.Context, Profile>) -> Unit) {
    val context = LocalContext.current
    val start = initial ?: Profile.sample
    var pet by remember { mutableStateOf(start.pet) }
    var name by remember { mutableStateOf(start.name) }
    var birthday by remember { mutableStateOf(start.birthday) }
    var pickingDate by remember { mutableStateOf(false) }
    val sign = ZodiacSign.of(birthday)
    val accent = Color(pet.accent)

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Text(title, fontSize = 32.sp, fontWeight = FontWeight.Bold)
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            AnimatedPet(pet, null, PetEmotion.HAPPY, 0, Modifier.size(140.dp))
        }
        PetKind.entries.chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { kind ->
                    val selected = kind == pet
                    Column(
                        Modifier.weight(1f).clip(RoundedCornerShape(16.dp))
                            .background(if (selected) Color(kind.accent).copy(alpha = 0.25f) else Color(0x0FFFFFFF))
                            .border(2.dp, if (selected) Color(kind.accent) else Color.Transparent, RoundedCornerShape(16.dp))
                            .clickable {
                                if (name.isBlank() || PetKind.entries.any { it.defaultName == name }) name = kind.defaultName
                                pet = kind
                            }
                            .padding(8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        StaticPet(kind, 0, null, Modifier.size(52.dp))
                        Text(stringResource(kind.speciesRes), fontSize = 11.sp, color = Color.Gray)
                    }
                }
            }
        }
        Card {
            OutlinedTextField(name, { name = it }, label = { Text(stringResource(R.string.pet_name)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.your_birthday), Modifier.weight(1f))
                TextButton(onClick = { pickingDate = true }) { Text(birthday.format(java.time.format.DateTimeFormatter.ofLocalizedDate(java.time.format.FormatStyle.MEDIUM)), color = accent) }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(sign.symbol, fontSize = 34.sp, color = accent)
                Column {
                    Text(stringResource(sign.nameRes), fontWeight = FontWeight.Bold)
                    Text("${stringResource(sign.elementSignRes)} · ${sign.dates(context.resources.configuration.locales[0])}", fontSize = 12.sp, color = Color.Gray)
                }
            }
        }
        if (pickingDate) {
            val state = rememberDatePickerState(
                initialSelectedDateMillis = birthday.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
                selectableDates = object : SelectableDates {
                    override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= System.currentTimeMillis()
                },
            )
            DatePickerDialog(
                onDismissRequest = { pickingDate = false },
                confirmButton = {
                    TextButton(onClick = {
                        state.selectedDateMillis?.let { birthday = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate() }
                        pickingDate = false
                    }) { Text("OK", color = accent) }
                },
                dismissButton = { TextButton(onClick = { pickingDate = false }) { Text(stringResource(android.R.string.cancel)) } },
            ) { DatePicker(state) }
        }
        Button(
            onClick = { onSave(context to Profile(pet, name.trim().ifEmpty { pet.defaultName }, birthday, initial?.accessory)) },
            modifier = Modifier.fillMaxWidth().height(52.dp),
            colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
        ) { Text(button, fontWeight = FontWeight.Bold, fontSize = 17.sp) }
    }
}

@Composable
private fun MyMessages(p: Profile, onBack: () -> Unit) {
    val context = LocalContext.current
    var list by remember { mutableStateOf(PetStore.customMessages(context)) }
    var draft by remember { mutableStateOf("") }
    val accent = Color(p.pet.accent)

    fun save(newList: List<String>) {
        list = newList
        PetStore.saveCustomMessages(context, newList)
        Pals.settingsChanged(context)
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = accent) }
            Text(stringResource(R.string.my_messages), fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        Card {
            OutlinedTextField(draft, { draft = it }, label = { Text(stringResource(R.string.write_message)) }, maxLines = 4, modifier = Modifier.fillMaxWidth())
            Button(
                onClick = {
                    draft.trim().takeIf { it.isNotEmpty() }?.let { save(list + it) }
                    draft = ""
                },
                enabled = draft.isNotBlank(),
                colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
            ) { Text(stringResource(R.string.add)) }
            Text(stringResource(R.string.my_messages_footer), fontSize = 12.sp, color = Color.Gray)
        }
        Text(stringResource(R.string.your_messages), fontWeight = FontWeight.Bold)
        if (list.isEmpty()) Text(stringResource(R.string.no_messages), color = Color.Gray)
        list.forEachIndexed { i, message ->
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(CardColor).padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(message, Modifier.weight(1f))
                IconButton(onClick = { save(list.filterIndexed { j, _ -> j != i }) }) { Icon(Icons.Outlined.Delete, null, tint = Color(0xFFFF6B6B)) }
            }
        }
    }
}
