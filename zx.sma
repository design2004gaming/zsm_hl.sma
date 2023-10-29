/*
* Half-Life: Zombie Mod X
* Version: 1.0
* Author: rtxa
*
* -- Information --
*
* Requires AMX Mod X 1.9 and it's recommended to use Bugfixed and Improved HL Release to avoid any issues with player's count.
*
* - Round System.
* - Infection Mode
*   - Humans spawns in different locations, the virus is released after a while and someone turns out into a zombie.
*   - Zombies must infect all humans to win.
*   - Humans must eliminate all zombies to win.
*   - Every infection gives you one frag, every zombie you kill gives you five frags.
*
* -- Credits --
*
* Anggara_Nothing, for some useful codes.
* Zombie model from CSO ported by Koshak.
* Most resources are from CSO.
*
*/

#include <amxmisc>
#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <hlstocks>
#include <msgstocks>

#define PLUGIN "Zombie Mod X"
#define PLUGIN_SHORT "ZX"
#define VERSION "1.0"
#define AUTHOR  "rtxa"

#pragma semicolon 1

// TaskIDs
enum (+= 100) {
	TASK_FIRSTROUND = 2019,
	TASK_ROUNDPRESTART,
	TASK_ROUNDSTART,
	TASK_ROUNDEND,
	TASK_FREEZEPERIOD,
	TASK_PLAYERSTATUS,
	TASK_ZOMBIEALERTSND,
	TASK_SENDTOSPEC,
	TASK_CHECKGAMESTATUS,
	TASK_ROUNDTIMER
};

new const WEAPONS_CLASSES[][] = {
	"weapon_357",
	"weapon_9mmAR",
	"weapon_9mmhandgun",
	"weapon_crossbow",
	"weapon_egon",
	"weapon_gauss",
	"weapon_handgrenade",
	"weapon_hornetgun",
	"weapon_rpg",
	"weapon_satchel",
	"weapon_shotgun",
	"weapon_snark",
	"weapon_tripmine",
	"weaponbox"
};

new const AMMO_CLASSES[][] = {
	"ammo_357",
	"ammo_9mmAR",
	"ammo_9mmbox",
	"ammo_9mmclip",
	"ammo_ARgrenades",
	"ammo_buckshot",
	"ammo_crossbow",
	"ammo_egonclip",
	"ammo_gaussclip",
	"ammo_glockclip",
	"ammo_mp5clip",
	"ammo_mp5grenades",
	"ammo_rpgclip"
};

new const ITEM_CLASSES[][] = {
	"item_longjump",
	"item_suit",
	"item_battery",
	"item_healthkit",
};

new const FUNC_CLASSES[][] = {
	"func_recharge",
	"func_healthcharger",
	"func_tank",
	"func_tankcontrols",
	"func_tanklaser",
	"func_tankmortar",
	"func_tankrocket",
};

new const NULL_SOUND[] = "common/null.wav";

// half-life default sounds for dmg and use
new const CBAR_HIT1[] = "weapons/cbar_hit1.wav";
new const CBAR_HIT2[] = "weapons/cbar_hit2.wav";
new const CBAR_HITBOD1[] = "weapons/cbar_hitbod1.wav";
new const CBAR_HITBOD2[] = "weapons/cbar_hitbod2.wav";
new const CBAR_HITBOD3[] = "weapons/cbar_hitbod3.wav";
new const GUNPICKUP2[] = "items/gunpickup2.wav";
new const WPN_SELECT[] = "common/wpn_select.wav"; // use
new const WPN_DENYSELECT[] = "common/wpn_denyselect.wav"; // can't use

// round ambience music
new const ROUND_AMBIENCE[][] = { "sound/zx/ambience1.mp3" };

// round sounds
new const SND_ROUND_DRAW[][] = { "zx/round_draw_1.wav" };
new const SND_ROUND_WIN_HUMAN[][] = { "zx/round_win_human_1.wav" };
new const SND_ROUND_WIN_ZOMBI[][] = { "zx/round_win_zombi_1.wav" };
new const SND_ZMB_COMING[][] = { "zx/zmb_coming_1.wav", "zx/zmb_coming_2.wav" };
new const SND_ROUND_START[] = "zx/round_start_1.wav";
new const SND_VOX_20SECREMAIN[] = "zx/vox/20secremain.wav";
new const SND_VOX_COUNT[][] = {
	"common/null.wav",
	"zx/vox/one.wav",
	"zx/vox/two.wav",
	"zx/vox/three.wav",
	"zx/vox/four.wav",
	"zx/vox/five.wav",
	"zx/vox/six.wav",
	"zx/vox/seven.wav",
	"zx/vox/eight.wav",
	"zx/vox/nine.wav",
	"zx/vox/ten.wav"
};

// human sounds
new const SND_HUMAN_DEATH[][] = { "zx/human_death_1.wav", "zx/human_death_2.wav" };

// zombie sounds
new const SND_ZMB_ALERT[][] = { "zx/zmb_alert_1.wav", "zx/zmb_alert_2.wav"};
new const SND_ZMB_DEATH[][] = { "zx/zmb_death_1.wav", "zx/zmb_death_2.wav" };
new const SND_ZMB_HITBOD[][] = { "zx/zmb_attack_1.wav", "zx/zmb_attack_2.wav", "zx/zmb_attack_3.wav" };
new const SND_ZMB_HITWALL[][] = { "zx/zmb_wall_1.wav", "zx/zmb_wall_2.wav", "zx/zmb_wall_3.wav" };
new const SND_ZMB_HURT[][] = { "zx/zmb_hurt_1.wav", "zx/zmb_hurt_2.wav" };

// zombie claws model
new const MDL_ZMB_CLAWS[] = "models/zx/v_claws_zombie.mdl";

#define IsPlayer(%0) (%0 > 0 && %0 <= MaxClients)

#define HUMAN_TEAMID 1
#define ZOMBIE_TEAMID 2

#define ZOMBIE_ALERT_DELAY 13.5

// because player can't be send to spectator instantly when he connects, player is gonna be alive for a thousandth of a second,
// so that can mess with counting functions for players and make rounds never end.
// to fix it, we need to make those functions ignore those players and all will be fine.
new gHasReallyJoined[MAX_PLAYERS + 1];

// players list
new gPlayers[MAX_PLAYERS];
new gPlayersAlive[MAX_PLAYERS];

// count
new gNumPlayers;
new gNumPlayersAlive;
new gNumHumans; // alives
new gNumZombies; // alives

// gamerules
new bool:gRoundStarted;

// timers in seconds
new gCountDown;
new gRoundTime;

// freeze period
new gFreezeTime;
new Float:gSpeedBeforeFreeze[MAX_PLAYERS + 1];

// thunder effect sprites
new gSprLaserDot;
new gSprLgtning;

// hud sync handles
new gPlayerHudSync;
new gRoundTimeHudSync;

// players classes (human, zombie, etc...)
new gPlayerClass[33];
enum { CLASS_HUMAN, CLASS_ZOMBIE };
new const gPlayerClassMlKeys[][] = { "CLASS_HUMAN", "CLASS_ZOMBIE" }; // multilingual keys

// hud player status color
new gHudColor[3];
new Float:gHudX;
new Float:gHudY;

// server cvars
new gCvarDebug;
new gCvarSky;
new gCvarLight;

new gCvarFirstRoundTime;
new gCvarMinPlayers;
new gCvarRoundTime;
new gCvarFreezeTime;

new gCvarHumanHealth;
new gCvarHumanArmor;
new gCvarHumanGravity;
new gCvarHumanMaxSpeed;
new gCvarHumansFrags;

new gCvarZombieHealth;
new gCvarZombieArmor;
new gCvarZombieGravity;
new gCvarZombieMaxSpeed;
new gCvarZombieFrags;

// Game mode name that should be displayed in server browser
public FwGetGameDescription() {
	forward_return(FMV_STRING, PLUGIN + " " + VERSION);
	return FMRES_SUPERCEDE;
}

public plugin_precache() {
	if (get_global_float(GL_teamplay) < 1.0)
		set_fail_state("Not in teamplay mode! Check that ^"mp_teamplay^" value is correct.");

	if (__count_teams() != 2)
		set_fail_state("Only 2 teams are required! Check that ^"mp_teamplay^" value is correct.");

	// precache models from mp_teamlist
	PrecacheTeamList();

	// round ambience music
	PrecacheMP3List(ROUND_AMBIENCE, sizeof ROUND_AMBIENCE);

	// round sounds
	precache_sound(SND_ROUND_START);
	precache_sound(SND_VOX_20SECREMAIN);
	PrecacheSoundList(SND_ROUND_WIN_HUMAN, sizeof SND_ROUND_WIN_HUMAN);
	PrecacheSoundList(SND_ROUND_WIN_ZOMBI, sizeof SND_ROUND_WIN_ZOMBI);
	PrecacheSoundList(SND_ROUND_DRAW, sizeof SND_ROUND_DRAW);
	PrecacheSoundList(SND_VOX_COUNT, sizeof SND_VOX_COUNT);
	PrecacheSoundList(SND_ZMB_COMING, sizeof SND_ZMB_COMING);

	// human sounds
	PrecacheSoundList(SND_HUMAN_DEATH, sizeof SND_HUMAN_DEATH);

	// zombie sounds
	PrecacheSoundList(SND_ZMB_HITWALL, sizeof SND_ZMB_HITWALL);
	PrecacheSoundList(SND_ZMB_HITBOD, sizeof SND_ZMB_HITBOD);
	PrecacheSoundList(SND_ZMB_ALERT, sizeof SND_ZMB_ALERT);
	PrecacheSoundList(SND_ZMB_HURT, sizeof SND_ZMB_HURT);
	PrecacheSoundList(SND_ZMB_DEATH, sizeof SND_ZMB_DEATH);

	// zombie models
	precache_model(MDL_ZMB_CLAWS);

	// thunder sprites
	gSprLaserDot = precache_model("sprites/laserdot.spr");
	gSprLgtning = precache_model("sprites/lgtning.spr");

	// plugin version
	create_cvar("zx_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);

	// misc cvars
	gCvarDebug = create_cvar("zx_debug", "0", FCVAR_SERVER);
	gCvarLight = create_cvar("zx_light", "f", FCVAR_SERVER);
	gCvarSky = create_cvar("zx_sky", "blood_", FCVAR_SERVER);

	// round cvars
	gCvarMinPlayers = create_cvar("zx_minplayers", "2", FCVAR_SERVER);
	gCvarFirstRoundTime = create_cvar("zx_firstroundtime", "15.0", FCVAR_SERVER);
	gCvarRoundTime = create_cvar("zx_roundtime", "240", FCVAR_SERVER);
	gCvarFreezeTime = create_cvar("zx_freezetime", "3.0", FCVAR_SERVER);

	// zombie cvars
	gCvarZombieHealth = create_cvar("zombie_health", "500", FCVAR_SERVER);
	gCvarZombieArmor = create_cvar("zombie_armor", "250", FCVAR_SERVER);
	gCvarZombieGravity = create_cvar("zombie_gravity", "0.5", FCVAR_SERVER);
	gCvarZombieMaxSpeed = create_cvar("zombie_maxspeed", "360.0", FCVAR_SERVER);
	gCvarZombieFrags = create_cvar("zombie_frags_infection", "1", FCVAR_SERVER);

	// human cvars
	gCvarHumanHealth = create_cvar("human_health", "100", FCVAR_SERVER);
	gCvarHumanArmor = create_cvar("human_armor", "0", FCVAR_SERVER);
	gCvarHumanGravity = create_cvar("human_gravity", "1.0", FCVAR_SERVER);
	gCvarHumanMaxSpeed = create_cvar("human_maxspeed", "300.0", FCVAR_SERVER);
	gCvarHumansFrags = create_cvar("human_frags_kill", "5", FCVAR_SERVER);

	// hud cvars
	bind_pcvar_float(create_cvar("zx_hud_x", "0.01", FCVAR_SERVER), gHudX);
	bind_pcvar_float(create_cvar("zx_hud_y", "0.1", FCVAR_SERVER), gHudY);

	new pcvar = create_cvar("zx_hud_color", "0 230 0", FCVAR_SERVER);
	hook_cvar_change(pcvar, "HookHudCvarChange");
	LoadColorsFromCvar(pcvar, gHudColor);

	// set custom sky
	new sky[32];
	get_pcvar_string(gCvarSky, sky, charsmax(sky));
	if (strlen(sky)) {
		set_cvar_string("sv_skyname", sky);
		PrecacheSky(sky);
	}
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	// multilingual
	register_dictionary("zx.txt");
	register_dictionary("zx_help.txt");

	RegisterHamPlayer(Ham_TakeDamage, "FwPlayerPreTakeDamage");
	RegisterHamPlayer(Ham_Killed, "FwPlayerPostKilled", true);
	RegisterHamPlayer(Ham_Spawn, "FwPlayerPreSpawn");

	// block zombie use and pick up of items excepting buttons
	RegisterHamList(Ham_Use, FUNC_CLASSES, sizeof FUNC_CLASSES, "FwFuncEntsUse");
	RegisterHamList(Ham_Touch, ITEM_CLASSES, sizeof ITEM_CLASSES, "FwItemsTouch");
	RegisterHamList(Ham_Touch, AMMO_CLASSES, sizeof AMMO_CLASSES, "FwItemsTouch");
	RegisterHamList(Ham_Touch, WEAPONS_CLASSES, sizeof WEAPONS_CLASSES, "FwItemsTouch");
	RegisterHamList(Ham_AddPlayerItem, WEAPONS_CLASSES, sizeof WEAPONS_CLASSES, "FwItemsTouch");

	register_forward(FM_GetGameDescription, "FwGetGameDescription");
	register_forward(FM_EmitSound, "FwEmitSound");

	// client cmds
	register_clcmd("zx_restart", "CmdRoundRestart", ADMIN_BAN, "HELP_RESTART", _, true);
	register_clcmd("zx_sethuman", "CmdSetHuman", ADMIN_BAN, "HELP_SETHUMAN", _, true);
	register_clcmd("zx_setzombie", "CmdSetZombie", ADMIN_BAN, "HELP_SETZOMBIE", _, true);
	register_clcmd("spectate", "CmdSpectate");
	register_clcmd("drop", "CmdDrop");

	// intermission mode
	register_event_ex("30", "EventIntermissionMode", RegisterEvent_Global);

	// debug cmds
	register_concmd("zx_userinfo", "CmdUserInfo", ADMIN_IMMUNITY);
	register_concmd("zx_roundinfo", "CmdRoundInfo", ADMIN_IMMUNITY);

	// create hud sync objects
	gPlayerHudSync = CreateHudSyncObj(); // show player's health, armor and class
	gRoundTimeHudSync = CreateHudSyncObj();

	// set map lightning level
	new light[32];
	get_pcvar_string(gCvarLight, light, charsmax(light));
	set_lights(light);

	// countdown for start the first round.
	gCountDown = get_pcvar_num(gCvarFirstRoundTime);
	FirstRoundCountdown();
}

public EventIntermissionMode() {
	// stop round
	gRoundStarted = false;
	remove_task(TASK_FIRSTROUND);
	remove_task(TASK_ROUNDPRESTART);
	remove_task(TASK_ROUNDSTART);
	remove_task(TASK_FREEZEPERIOD);

	for (new i = 1; i < MaxClients; i++)
		remove_task(i + TASK_ZOMBIEALERTSND);
}

public FirstRoundCountdown() {
	gCountDown--;
	client_print(0, print_center, "%l", "ROUND_FIRSTROUND", gCountDown);

	if (gCountDown == 0) {
		RoundPreStart();
		return;
	}
	set_task(1.0, "FirstRoundCountdown", TASK_FIRSTROUND);
}

public RoundPreStart() {
	if (get_pcvar_num(gCvarDebug))
		log_amx("Function: RoundPreStart");

	gRoundStarted = false;

	// remove tasks to avoid overlap
	remove_task(TASK_FIRSTROUND);
	remove_task(TASK_ROUNDPRESTART);
	remove_task(TASK_ROUNDSTART);
	remove_task(TASK_FREEZEPERIOD);
	remove_task(TASK_ROUNDTIMER);

	// stop countdown sound
	Speak(0, NULL_SOUND);
	client_cmd(0, "mp3 stop");

	// reset map stuff
	ResetMap();

	// get players count
	zx_get_players(gPlayers, gNumPlayers);

	// to all players...
	new player;
	for (new i; i < gNumPlayers; i++) {
		player = gPlayers[i];
		SetHuman(player, false);
		if (hl_get_user_spectator(player))
			zx_set_user_spectator(player, false);
		else
			zx_user_spawn(player);
	}

	// after freeze period, start with infection countdown
	StartFreezePeriod();
}

public RoundStartCountDown() {
	if (gCountDown == 20) {
		Speak(0, SND_ROUND_START);
		PlaySound(0, SND_VOX_20SECREMAIN);
		PlayMp3(0, ROUND_AMBIENCE[random(sizeof ROUND_AMBIENCE)]);
	} else if (gCountDown <= 10 && gCountDown > 0) {
		PlaySound(0, SND_VOX_COUNT[gCountDown]);
	} else if (gCountDown <= 0) {
		RoundStart();
		return;
	}
	client_print(0, print_center, "%l", "ROUND_COUNTDOWN", gCountDown);

	gCountDown--;

	set_task(1.0, "RoundStartCountDown", TASK_ROUNDPRESTART);
}

public RoundStart() {
	if (get_pcvar_num(gCvarDebug))
		log_amx("Function: RoundStart");

	// clean center msgs
	client_print(0, print_center, "");

	zx_get_players(gPlayers, gNumPlayers);

	// stop any sound from round countdown
	Speak(0, NULL_SOUND);

	new minPlayers = get_pcvar_num(gCvarMinPlayers);

	// check if there are enough players alive to start a round
	zx_get_players_alive(gPlayersAlive, gNumPlayersAlive);
	if (gNumPlayersAlive < minPlayers) {
		if (gNumPlayers > 0) { // avoid show this message when sv is empty
			client_print(0, print_chat, "[%s %s] %l", PLUGIN_SHORT, VERSION, "ROUND_MINPLAYERS", minPlayers);
			client_print(0, print_center, "%l", "ROUND_RESTART");
		}
		set_task(5.0, "RoundPreStart", TASK_ROUNDPRESTART);
		return;
	}

	new randomPlayer = gPlayersAlive[random(gNumPlayersAlive)];

	// turn a random human in zombie
	DeathMsg(randomPlayer, 0, "virus");
	SetZombie(randomPlayer);

	gRoundStarted = true;

	// set round time
	StartRoundTimer(get_pcvar_num(gCvarRoundTime));
}


public RoundEnd() {
	if (get_pcvar_num(gCvarDebug))
		log_amx("Function: RoundEnd");

	gRoundStarted = false;

	zx_get_team_alives(gNumHumans, HUMAN_TEAMID);
	zx_get_team_alives(gNumZombies, ZOMBIE_TEAMID);

	if (gNumHumans > 0 && !gNumZombies) { // humans win
		client_print(0, print_center, "%l", "ROUND_HUMANSWIN");
		PlaySound(0, SND_ROUND_WIN_HUMAN[random(sizeof SND_ROUND_WIN_HUMAN)]);
	} else if (gNumZombies > 0 && !gNumHumans) { // zombies win
		client_print(0, print_center, "%l", "ROUND_ZOMBIESWIN");
		PlaySound(0, SND_ROUND_WIN_ZOMBI[random(sizeof SND_ROUND_WIN_ZOMBI)]);
	} else { // draw
		client_print(0, print_center, "%l", "ROUND_DRAW");
		PlaySound(0, SND_ROUND_DRAW[random(sizeof SND_ROUND_DRAW)]);
	}

	SetAllGodMode();

	// call for a new round
	set_task(8.0, "RoundPreStart", TASK_ROUNDPRESTART);
}

public CheckGameStatus() {
	if (!gRoundStarted || task_exists(TASK_ROUNDEND))
		return;

	if (get_pcvar_num(gCvarDebug))
		log_amx("Function: CheckGameStatus");

	zx_get_team_alives(gNumHumans, HUMAN_TEAMID);
	zx_get_team_alives(gNumZombies, ZOMBIE_TEAMID);

	// finish round when there are no zombies or humans alive
	// note: allowing to delay round end, it let us get a draw when last 2 players kill each other
	if (gNumHumans < 1 || gNumZombies < 1)
		set_task(0.5, "RoundEnd", TASK_ROUNDEND);
}

public client_putinserver(id) {
	gHasReallyJoined[id] = false;
	set_task(0.1, "TaskPutInServer", id);
}

// Some things have to be delayed to be able to work, I explain you why for some.
public TaskPutInServer(id) {
	TaskShowPlayerStatus(id + TASK_PLAYERSTATUS);
	hl_set_teamnames(id, fmt("%l", "TEAMNAME_HUMANS"), fmt("%l", "TEAMNAME_ZOMBIES")); // message isn't received by the client at that moment
	hl_set_user_spectator(id, true); // bots can't be send to spec, they're invalid in putinserver. Also, it cause issues with scoreboard on real clients.
	gHasReallyJoined[id] = true;
}

public client_remove(id) {
	remove_task(id + TASK_PLAYERSTATUS);
	CheckGameStatus();
}

public client_kill(id) {
	return PLUGIN_HANDLED; // block kill cmd
}

public FwPlayerPreSpawn(id) {
	// if player has to spec, don't let him spawn...
	if (task_exists(TASK_SENDTOSPEC + id))
		return HAM_SUPERCEDE;
	return HAM_IGNORED;
}

public FwItemsTouch(entity, caller) {
	if (IsPlayer(caller) && hl_get_user_team(caller) == ZOMBIE_TEAMID)
		return HAM_SUPERCEDE;
	return HAM_IGNORED;
}

public FwFuncEntsUse(entity, caller, activator, use_type) {
	if (use_type == USE_SET && hl_get_user_team(caller) == ZOMBIE_TEAMID)
		return HAM_SUPERCEDE;
	return HAM_IGNORED;
}

public FwPlayerPostKilled(victim, attacker) {
	// give points to attacker by team
	if (victim != attacker && is_user_connected(attacker))
		if (hl_get_user_team(victim) == ZOMBIE_TEAMID) {
			PlaySound(0, SND_ZMB_DEATH[random(sizeof SND_ZMB_DEATH)]);
			hl_set_user_frags(attacker,  get_user_frags(attacker) + (get_pcvar_num(gCvarHumansFrags) - 1));
		} else
			hl_set_user_frags(attacker,  get_user_frags(attacker) + (get_pcvar_num(gCvarZombieFrags) - 1));

	// send victim to spec
	set_task(3.0, "SendToSpec", victim + TASK_SENDTOSPEC);

	CheckGameStatus();

	return HAM_IGNORED;
}

public FwPlayerPreTakeDamage(victim, inflictor, attacker, Float:damage, damagetype) {
	if (!is_user_alive(victim) || !IsPlayer(attacker))
		return HAM_IGNORED;

	new victimTeam = hl_get_user_team(victim);
	new attackerTeam = hl_get_user_team(attacker);

	// human attacks zombie
	if (victimTeam == ZOMBIE_TEAMID && attackerTeam == HUMAN_TEAMID) {
		static Float:zombieDmgTime[MAX_PLAYERS + 1];
		if (zombieDmgTime[victim] <= get_gametime()) {
			zombieDmgTime[victim] = get_gametime() + 0.3;
			emit_sound(victim, CHAN_BODY, SND_ZMB_HURT[random(sizeof SND_ZMB_HURT)], VOL_NORM, 0.35, 0, random_num(95, 105));
			fade_user_screen(victim, 0.5, 2.0, ScreenFade_FadeIn, 255, 32, 32, 75);
		}
	} else if (attackerTeam == ZOMBIE_TEAMID && victimTeam == HUMAN_TEAMID) { // zombie attacks human
		// if damage isn't from his claws, block it
		if (!IsPlayer(inflictor))
			return HAM_SUPERCEDE;

		// change claws damage
		if (get_user_weapon(attacker) == HLW_CROWBAR) {
			switch(damage) {
				case 25.0: SetHamParamFloat(4, 75.0); // body hit
				case 75.0: SetHamParamFloat(4, 100.0); // head hit
			}
			SetHamParamInteger(5, DMG_ALWAYSGIB); // always gib human
		}

		// note: sometimes it shows wrong team color
		// maybe, because the message is sent directly to the player, but the current team of all players from client is not updated yet,
		// until it gets to UpdateUserInfo, maybe delaying the deathmsg to the next frame will fix it, but it too much work, i prefer to keep it simple.
		DeathMsg(victim, attacker, "virus");

		// make victim a zombie
		SetZombie(victim);

		// give points for infection to attacker and add a death to victim
		hl_set_user_deaths(victim, hl_get_user_deaths(victim) + 1);
		hl_set_user_frags(attacker, get_user_frags(attacker) + 1);

		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public ZombieAlertSnd(taskid) {
	new id = taskid - TASK_ZOMBIEALERTSND;

	if (!is_user_alive(id) || hl_get_user_team(id) == HUMAN_TEAMID)
		return;

	emit_sound(id, CHAN_AUTO, SND_ZMB_ALERT[random(sizeof SND_ZMB_ALERT)], VOL_NORM, 0.50, 0, random_num(95, 105));
	set_task(ZOMBIE_ALERT_DELAY, "ZombieAlertSnd", taskid);
}

public SetZombieClaws(id) {
	// crowbar is gonna be his claws
	give_item(id, "weapon_crowbar");
	// weapon in first person
	set_pev(id, pev_viewmodel2, MDL_ZMB_CLAWS);
	// remove weapon from third person
	set_pev(id, pev_weaponmodel2, "");
}

SetZombie(id, checkGameStatus = true, screenEffects = true) {
	if (get_pcvar_num(gCvarDebug))
		log_amx("Function: SetZombie");

	remove_task(id+TASK_ZOMBIEALERTSND);

	if (!is_user_connected(id))
		return;

	gPlayerClass[id] = CLASS_ZOMBIE;

	ChangePlayerTeam(id, ZOMBIE_TEAMID);

	hl_strip_user_weapons(id);

	// give zombie claws
	SetZombieClaws(id);

	// health, armor, gravity, speed and lj
	set_user_health(id, get_pcvar_num(gCvarZombieHealth));
	set_user_armor(id, get_pcvar_num(gCvarZombieArmor));
	set_user_gravity(id, get_pcvar_float(gCvarZombieGravity)); // 0.5 would be like sv_gravity 400
	set_user_maxspeed(id, get_pcvar_float(gCvarZombieMaxSpeed));
	hl_set_user_longjump(id, true, false);

	// screen effects
	if (screenEffects) {
		fade_user_screen(id, 0.5, 3.0, ScreenFade_FadeIn, 255, 32, 32, 180);
		shake_user_screen(id, 16.0, 4.0, 16.0);
	}

	// thunder effect
	LightningEffect(id);

	// become zombie sound
	PlaySound(0, SND_ZMB_COMING[random(sizeof SND_ZMB_COMING)]);
	emit_sound(id, CHAN_AUTO, SND_HUMAN_DEATH[random(sizeof SND_HUMAN_DEATH)], VOL_NORM, 0.35, 0, random_num(95, 105));
	set_task(ZOMBIE_ALERT_DELAY, "ZombieAlertSnd", id + TASK_ZOMBIEALERTSND);

	if (checkGameStatus)
		CheckGameStatus();
}

SetHuman(id, bool:checkGameStatus = true) {
	if (get_pcvar_num(gCvarDebug))
		log_amx("Function: SetHuman");

	if (!is_user_connected(id))
		return;

	ChangePlayerTeam(id, HUMAN_TEAMID);

	gPlayerClass[id] = CLASS_HUMAN;

	// health, armor, gravity, speed
	set_user_health(id, get_pcvar_num(gCvarHumanHealth));
	set_user_armor(id, get_pcvar_num(gCvarHumanArmor));
	set_user_gravity(id, get_pcvar_float(gCvarHumanGravity)); // 1.0 would be like sv_gravity 800
	set_user_maxspeed(id, get_pcvar_float(gCvarHumanMaxSpeed));

	if (checkGameStatus)
		CheckGameStatus();

	return;
}

public SendToSpec(taskid) {
	new id = taskid - TASK_SENDTOSPEC;
	if (!is_user_alive(id) || is_user_bot(id))
		hl_set_user_spectator(id, true);
}

stock GetLightningStart(origin[3]) {
	new Float:originThunder[3];
	originThunder[0] = float(origin[0]);
	originThunder[1] = float(origin[1]);
	originThunder[2] = float(origin[2]);

	while(engfunc(EngFunc_PointContents, originThunder) == CONTENTS_EMPTY)
		originThunder[2] += 5.0;

	// uncomment this if you want thunder only come out from sky
	//return engfunc(EngFunc_PointContents, originThunder) == CONTENTS_SKY ? floatround(originThunder[2]) : origin[2];
	return floatround(originThunder[2]);
}

stock LightningEffect(id) {
	new footPos[3];
	GetUserFootOrigin(id, footPos);

	// thunder falls on the zombie
	new lgntningPos[3]; lgntningPos = footPos;
	lgntningPos[2] = GetLightningStart(footPos);
	te_create_beam_between_points(footPos, lgntningPos, gSprLgtning, _, _, 10, 125, 30, 255, 0, 0, 230, 100);

	// beam disc on floor
	new axis[3]; axis = footPos;
	axis[2] += 200; // beam radius
	te_create_beam_disk(footPos, gSprLgtning, axis, 0, 0, 10, _, _, 255, 0, 0, 200);

	// drop red spheres
	new eyesPos[3];
	get_user_origin(id, eyesPos, 1);
	te_create_model_trail(footPos, eyesPos, gSprLaserDot, 10, 10, 3, 25, 10); // note: 40 balls will overflow

	new origin[3];
	get_user_origin(id, origin);

	// red light for 3 seconds
	te_create_dynamic_light(origin, 20, 255, 0, 0, 30, 30);
}

stock GetUserFootOrigin(id, origin[3]) {
	new Float:temp, Float:ground[3];
	pev(id, pev_absmin, ground);
	temp = ground[2];
	pev(id, pev_origin, ground);
	ground[2] = temp + 2.0;

	for (new i; i < 3; i++) {
		origin[i] = floatround(ground[i]);
	}
}


public StartFreezePeriod() {
	for (new i; i < gNumPlayers; i++) {
		FreezePlayer(gPlayers[i]);
	}
	gFreezeTime = get_pcvar_num(gCvarFreezeTime);
	TaskFreezePeriod();
}

public TaskFreezePeriod() {
	if (gFreezeTime <= 0) {
		zx_get_players(gPlayers, gNumPlayers);
		for (new i; i < gNumPlayers; i++) {
			FreezePlayer(gPlayers[i], false);
		}
		// countdown for start round
		gCountDown = 20;
		RoundStartCountDown();
		return;
	}
	client_print(0, print_center, "%l", "ROUND_FREEZE", gFreezeTime);

	gFreezeTime--;

	set_task(1.0, "TaskFreezePeriod", TASK_FREEZEPERIOD);
}

FreezePlayer(id, freeze = true) {
	if (freeze) {
		gSpeedBeforeFreeze[id] = get_user_maxspeed(id);
		set_user_maxspeed(id, 1.0);
		BlockPlayerWeapons(id, float(get_pcvar_num(gCvarFreezeTime)));
	} else {
		set_user_maxspeed(id, gSpeedBeforeFreeze[id]);
	}
}

BlockPlayerWeapons(id, Float:time) {
	new weapon;
	for (new i = 1; i < 6; i++) {
		weapon = get_ent_data_entity(id, "CBasePlayer", "m_rgpPlayerItems", i);
		while (weapon != -1) {
			set_ent_data_float(weapon, "CBasePlayerWeapon", "m_flNextPrimaryAttack", time);
			set_ent_data_float(weapon, "CBasePlayerWeapon", "m_flNextSecondaryAttack", time);
			weapon = get_ent_data_entity(weapon, "CBasePlayerItem", "m_pNext");
		}
	}
}

StartRoundTimer(seconds) {
	gRoundTime = seconds;
	RoundTimerThink();
	set_task_ex(1.0, "RoundTimerThink", TASK_ROUNDTIMER, _, _, SetTask_Repeat);
}

public RoundTimerThink() {
	ShowRoundTimer();
	if (gRoundStarted) {
		if (gRoundTime > 0)
			gRoundTime--;
		else
			RoundEnd();
	}
}

public ShowRoundTimer() {
	new r, g, b;
	if (gRoundTime >= 120) { // green color
		r = 0;
		g = 255;
		b = 0;
	} else if (gRoundTime >= 60) { // brown color
		r = 250;
		g = 170;
		b = 0;
	} else { // red color
		r = 255;
		g = 50;
		b = 50;
	}

	set_hudmessage(r, g, b, 0.01, -0.1, 0, 0.01, gRoundStarted ? 600.0 : 1.0, 0.2, 0.2);
	ShowSyncHudMsg(0, gRoundTimeHudSync, "%l: %i:%02i", "ROUND_TIMELEFT", gRoundTime / 60, gRoundTime % 60);
}

public FwEmitSound(id, channel, sample[], Float:volume, Float:attn, flag, pitch) {
	if (!is_user_connected(id) || hl_get_user_team(id) != ZOMBIE_TEAMID)
		return FMRES_IGNORED;

	// replace default sounds with zombie sounds.
	if (equal(sample, CBAR_HIT1) || equal(sample, CBAR_HIT2)) {
		emit_sound(id, channel, SND_ZMB_HITWALL[random(sizeof SND_ZMB_HITWALL)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
		return FMRES_SUPERCEDE;
	} else if (equal(sample, CBAR_HITBOD1) || equal(sample, CBAR_HITBOD2) || equal(sample, CBAR_HITBOD3)) {
		emit_sound(id, channel, SND_ZMB_HITBOD[random(sizeof SND_ZMB_HITBOD)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
		return FMRES_SUPERCEDE;
	} else if (equal(sample, WPN_DENYSELECT) || equal(sample, WPN_SELECT) || equal(sample, GUNPICKUP2)) { // remove +use sounds
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

public CmdSpectate(id) {
	return PLUGIN_HANDLED;
}

public CmdDrop(id) {
	// don't let to zombie drop his claws
	if (hl_get_user_team(id) == ZOMBIE_TEAMID) {
		client_print(id, print_console, "Can you drop part of you arm?"); // GoT
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public CmdRoundRestart(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	RoundPreStart();
	return PLUGIN_HANDLED;
}

public CmdRoundInfo(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	PrintRoundInfo(id);
	return PLUGIN_HANDLED;
}

public CmdUserInfo(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new target[32];
	read_argv(1, target, charsmax(target));

	if (equal(target, "")) {
		PrintUserInfo(id, id);
		return PLUGIN_HANDLED;
	}

	new player = cmd_target(id, target);

	if (!player)
		return PLUGIN_HANDLED;

	PrintUserInfo(id, player);
	return PLUGIN_HANDLED;
}

public CmdSetHuman(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new target = id;

	new arg[MAX_NAME_LENGTH];
	read_argv(1, arg, charsmax(arg));

	if (!equal(arg, ""))
		target = cmd_target(id, arg, CMDTARGET_ONLY_ALIVE);

	if (target)
		SetHuman(target);

	return PLUGIN_HANDLED;
}

public CmdSetZombie(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new target = id;

	new arg[MAX_NAME_LENGTH];
	read_argv(1, arg, charsmax(arg));

	if (!equal(arg, ""))
		target = cmd_target(id, arg, CMDTARGET_ONLY_ALIVE);

	if (target)
		SetZombie(target);

	return PLUGIN_HANDLED;
}

stock PrintUserInfo(caller, target) {
	new model[16], m_szTeamName[16];
	new team = hl_get_user_team(target, model, charsmax(model));
	get_ent_data_string(target, "CBasePlayer", "m_szTeamName", m_szTeamName, charsmax(m_szTeamName));

	new iuser1 = pev(target, pev_iuser1);
	new iuser2 = pev(target, pev_iuser2);

	new dead = pev(target, pev_deadflag);

	new alive = is_user_alive(target);

	new modelIndex = pev(target, pev_modelindex);

	client_print(caller, print_chat, "[Player Info] Team: %i; Model: %s; m_szTeamName: %s; Model Index %i;", team, model, m_szTeamName, modelIndex);
	client_print(caller, print_chat, "[Player Info] iuser1: %i; iuser2: %i Alive: %i; Dead: %i", iuser1, iuser2, alive, dead);
}

stock PrintRoundInfo(id) {
	new text[192];
	formatex(text, charsmax(text), "[Round Info] Alives: %i; Humans: %i; Zombies: %i; RoundStarted: %i", gNumPlayersAlive, gNumHumans, gNumZombies, gRoundStarted);
	client_print(id, print_chat, "%s", text);
	server_print("%s", text);
}

public TaskShowPlayerStatus(taskid) {
	new id = taskid - TASK_PLAYERSTATUS;
	ShowPlayerStatus(id);
	set_task(0.5, "TaskShowPlayerStatus", taskid);
}

stock ShowPlayerStatus(id) {
	new target = id;

	new r, g, b;
	r = gHudColor[0];
	g = gHudColor[1];
	b = gHudColor[2];

	new mlKey[32] = "HUD_STATUS";
	if (!is_user_connected(id) || is_user_bot(id))
		return;

	if (hl_get_user_spectator(id)) {
		target = pev(id, pev_iuser2);
		if (is_user_connected(target)) {
			mlKey = "HUD_STATUS_SPEC";
			r = g = b = 230; // white color
		} else
			return;
	}

	set_hudmessage(r, g, b, gHudX, gHudY, 0, 6.0, 120.0, 0.0, 0.0);
	ShowSyncHudMsg(id, gPlayerHudSync, "%l^n%s %s^n", mlKey, target, clamp(pev(target, pev_health), 0), pev(target, pev_armorvalue), gPlayerClassMlKeys[gPlayerClass[target]], PLUGIN, VERSION);
}

zx_get_players(players[MAX_PLAYERS], &num) {
	num = 0;
	for (new id = 1; id <= MaxClients; id++) {
		if (!is_user_hltv(id) && is_user_connected(id) && gHasReallyJoined[id]) {
			players[num++] = id;
		}
	}
}

zx_get_players_alive(players[MAX_PLAYERS], &num) {
	num = 0;
	for (new id = 1; id <= MaxClients; id++) {
		if (is_user_alive(id) && gHasReallyJoined[id]) {
			players[num++] = id;
		}
	}
}

// get_players() by team give false values sometimes, use this.
zx_get_team_alives(&teamAlives, teamindex) {
	teamAlives = 0;
	for (new id = 1; id <= MaxClients; id++)
		if (is_user_alive(id) && hl_get_user_team(id) == teamindex && gHasReallyJoined[id])
			teamAlives++;
}

zx_set_user_spectator(client, bool:spectator = true) {
	if (!spectator)
		remove_task(client + TASK_SENDTOSPEC); // remove task to let him respawn
	hl_set_user_spectator(client, spectator);
}

zx_user_spawn(client) {
	remove_task(client + TASK_SENDTOSPEC); // if you dont remove this, he will not respawn
	hl_user_spawn(client);
}

ResetMap() {
	ClearCorpses();
	ClearField();
	RespawnItems();
	ResetFuncChargers();
}

ClearCorpses() {
	new ent;
	while ((ent = find_ent_by_class(ent, "bodyque")))
		set_pev(ent, pev_effects, EF_NODRAW);
}

// this will clean entities like tripmines, satchels, etc...
ClearField() {
	static const fieldEnts[][] = { "bolt", "monster_snark", "monster_satchel", "monster_tripmine", "beam", "weaponbox" };

	for (new i; i < sizeof fieldEnts; i++)
		remove_entity_name(fieldEnts[i]);

	new ent;
	while ((ent = find_ent_by_class(ent, "rpg_rocket")))
		set_pev(ent, pev_dmg, 0);

	ent = 0;
	while ((ent = find_ent_by_class(ent, "grenade")))
		set_pev(ent, pev_dmg, 0);
}

// this will reset hev and health chargers
ResetFuncChargers() {
	new classname[32];
	for (new i; i < global_get(glb_maxEntities); i++) {
		if (pev_valid(i)) {
			pev(i, pev_classname, classname, charsmax(classname));
			if (equal(classname, "func_recharge")) {
				set_pev(i, pev_frame, 0);
				set_pev(i, pev_nextthink, 0);
				set_ent_data(i, "CRecharge", "m_iJuice", 30);
			} else if (equal(classname, "func_healthcharger")) {
				set_pev(i, pev_frame, 0);
				set_pev(i, pev_nextthink, 0);
				set_ent_data(i, "CWallHealth", "m_iJuice", 75);
			}
		}
	}
}

// This will respawn all weapons, ammo and items of the map
RespawnItems() {
	new classname[32];
	for (new i; i < global_get(glb_maxEntities); i++) {
		if (pev_valid(i)) {
			pev(i, pev_classname, classname, charsmax(classname));
			if (contain(classname, "weapon_") != -1 || contain(classname, "ammo_") != -1 || contain(classname, "item_") != -1) {
				set_pev(i, pev_nextthink, get_gametime());
			}
		}
	}
}

// Change player team by teamid without killing him.
ChangePlayerTeam(id, teamId) {
	static gameTeamMaster, gamePlayerTeam, spawnFlags;

	if (!gameTeamMaster) {
		gameTeamMaster = create_entity("game_team_master");
		set_pev(gameTeamMaster, pev_targetname, "changeteam");
	}

	if (!gamePlayerTeam) {
		gamePlayerTeam = create_entity("game_player_team");
		DispatchKeyValue(gamePlayerTeam, "target", "changeteam");
	}

	set_pev(gamePlayerTeam, pev_spawnflags, spawnFlags);

	DispatchKeyValue(gameTeamMaster, "teamindex", fmt("%i", teamId - 1));

	ExecuteHamB(Ham_Use, gamePlayerTeam, id, 0, USE_ON, 0.0);
}

// Execute this post client_putinserver
// Change team names from VGUI Menu and VGUI Scoreboard (the last one only works with vanilla clients)
hl_set_teamnames(id, any:...) {
	new teamNames[10][16];
	new numTeams = clamp(numargs() - 1, 0, 10);

	for (new i; i < numTeams; i++)
		format_args(teamNames[i], charsmax(teamNames[]), 1 + i);

	// Send new team names
	message_begin(MSG_ONE, get_user_msgid("TeamNames"), _, id);
	write_byte(numTeams);
	for (new i; i < numTeams; i++)
		write_string(teamNames[i]);
	message_end();
}

SetAllGodMode() {
	zx_get_players(gPlayers, gNumPlayers);
	for (new i; i < gNumPlayers; i++)
		set_user_godmode(gPlayers[i], true);
}

DeathMsg(victim, attacker, const type[]) {
	static deathMsg;
	if (!deathMsg)
		deathMsg = get_user_msgid("DeathMsg");

	message_begin(MSG_ALL, deathMsg);
	write_byte(attacker);
	write_byte(victim);
	write_string(type);
	message_end();
}

PrecacheTeamList() {
	new teamlist[192], teamnames[HL_MAX_TEAMS][HL_TEAMNAME_LENGTH];
	get_cvar_string("mp_teamlist", teamlist, charsmax(teamlist));

	new nIdx, nLen = (1 + copyc(teamnames[nIdx], charsmax(teamnames[]), teamlist, ';'));

	while (nLen < strlen(teamlist) && ++nIdx < HL_MAX_TEAMS)
		nLen += (1 + copyc(teamnames[nIdx], charsmax(teamnames[]), teamlist[nLen], ';'));

	new file[128];
	for (new i; i < HL_MAX_TEAMS; i++) {
		formatex(file, charsmax(file), "models/player/%s/%s.mdl", teamnames[i], teamnames[i]);
		if (file_exists(file))
			engfunc(EngFunc_PrecacheModel, file);
	}
}

PrecacheSky(const sky[]) {
	static const skyPostFix[][] = { "rt", "lf", "bk", "ft", "dn", "up" };

	new file[192];
	for (new i; i < sizeof skyPostFix; i++) {
		formatex(file, charsmax(file), "gfx/env/%s%s.tga", sky, skyPostFix[i]);
		if (!file_exists(file)) {
			log_amx("Sky files don't exist! Aborting precache.");
			return;
		}
		precache_generic(file);
	}
}

PlaySound(id, const sound[]) {
	new snd[128];
	RemoveExtension(sound, snd, charsmax(snd), ".wav"); // remove wav extension to avoid "missing sound file _period.wav"
	client_cmd(id, "spk ^"%s^"", snd);
}

PlayMp3(id, const file[]) {
	client_cmd(id, "mp3 loop %s", file);
}

Speak(id, const speak[]) {
	new spk[128];
	RemoveExtension(speak, spk, charsmax(spk), ".wav"); // remove wav extension to avoid "missing sound file _period.wav"
	client_cmd(id, "speak ^"%s^"", spk);
}

RemoveExtension(const input[], output[], length, const ext[]) {
	copy(output, length, input);

	new idx = strlen(input) - strlen(ext);
	if (idx < 0) return 0;

	return replace(output[idx], length, ext, "");
}

PrecacheSoundList(const sndList[][], size) {
	for (new i; i < size; i++)
		precache_sound(sndList[i]);
}

PrecacheMP3List(const sndList[][], size) {
	for (new i; i < size; i++)
		precache_generic(sndList[i]);
}

RegisterHamList(Ham:function, const EntityClassList[][], size, const Callback[], Post = 0, bool:specialBot = false) {
	for (new i; i < size; i++)
		RegisterHam(function, EntityClassList[i], Callback, Post, specialBot);
}

public HookHudCvarChange(pcvar, const old_value[], const new_value[]) {
	StrToRGB(new_value, gHudColor);
}

LoadColorsFromCvar(pcvar, rgb[3]) {
	new color[12];
	get_pcvar_string(pcvar, color, charsmax(color));
	StrToRGB(color, rgb);
}

// the input string must be in this format "r g b" e.g. "128 0 256"
Float:StrToRGB(const string[], rgb[3]) {
	new arg[3][12]; // hold parsed vector
	parse(string, arg[0], charsmax(arg[]), arg[1], charsmax(arg[]), arg[2], charsmax(arg[]));

	for (new i; i < sizeof arg; i++)
		rgb[i] = clamp(str_to_num(arg[i]), 0, 255);
}
