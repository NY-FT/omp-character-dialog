#include <YSI_Data\y_iterate>
#include <YSI_Coding\y_hooks>

/**
 * # Header
 */

#define MAX_ACCOUNT_CHARACTERS      (5)

#define MIN_CHARACTER_AGE           (18)
#define MAX_CHARACTER_AGE           (32)

#define DEFAULT_SPAWN_X             (1756.7087)
#define DEFAULT_SPAWN_Y             (-1903.5756)
#define DEFAULT_SPAWN_Z             (13.5643)
#define DEFAULT_SPAWN_A             (270.0000)

static enum _:E_CHARACTER_LOAD_DATA {
    E_CHARACTER_MONEY,
    E_CHARACTER_SCORE,
    E_CHARACTER_SKIN_ID,
    E_CHARACTER_WORLD_ID,
    E_CHARACTER_INTERIOR_ID,
    E_CHARACTER_WANTED,
    Float:E_CHARACTER_HEALTH,
    Float:E_CHARACTER_ARMOUR,
    Float:E_CHARACTER_X,
    Float:E_CHARACTER_Y,
    Float:E_CHARACTER_Z,
    Float:E_CHARACTER_A
};

static enum E_CHARACTER_DATA {
    DBID:E_CHARACTER_DATABASE_ID,
    E_CHARACTER_NAME[MAX_PLAYER_NAME + 1]
};

static
    character[MAX_PLAYERS][MAX_ACCOUNT_CHARACTERS][E_CHARACTER_DATA]
;

static const
    characterDefaultSkinList[][] =
{
    /**
     * 0: Male
     * 1: Female
     */

    {0, 18}, {0, 60}, {0, 230},
    {1, 13}, {1, 56}, {1, 192}
};

static
    bool:playerIsLogged[MAX_PLAYERS char],
    playerSelectCharacterGender[MAX_PLAYERS char],
    playerSelectCharacterAge[MAX_PLAYERS char],
    playerSelectCharacterSkin[MAX_PLAYERS],
    playerSelectCharacterSlotID[MAX_PLAYERS char]
;

new
    Iterator:PlayerCharacter[MAX_PLAYERS]<MAX_ACCOUNT_CHARACTERS>
;

/**
 * # Forwards
 */

forward OnCharacterSpawn(playerid);
forward OnCharacterLogOut(playerid);

forward OnCharacterCheck(playerid);
forward OnCharacterRetrieve(playerid, slotid);
forward OnCharacterNameCheck(playerid, const name[]);
forward OnCharacterInsertDatabase(playerid, slotid);

/**
 * # Internal
 */

static CheckCharacterDatabase(playerid) {
    new
        query[128]
    ;

    mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "SELECT `id`, `name` FROM `characters` WHERE `account_id` = %i;", _:GetAccountDatabaseID(playerid));
    mysql_tquery(MYSQL_DEFAULT_HANDLE, query, "OnCharacterCheck", "i", playerid);
}

static ShowCreateCharacterDialog(playerid) {
    new
        menu[MAX_PLAYER_NAME * MAX_ACCOUNT_CHARACTERS + 32] = "Select or create a character:\n"
    ;

    foreach (new i: PlayerCharacter[playerid]) {
        format(menu, sizeof (menu), "%s%s\n", menu, character[playerid][i][E_CHARACTER_NAME]);
    }

    if (Iter_NonFull(PlayerCharacter[playerid])) {
        strcat(menu, "{98FB98}+ Create character");
    }

    ShowPlayerDialog(playerid, DIALOG_CHARACTER_SELECTION, DIALOG_STYLE_TABLIST_HEADERS, "Character Selection", menu, "Select", "Leave");
}

static SelectCharacterAgeDialog(playerid) {
    new
        menu[128] = "Select your character's age:\n"
    ;

    for (new i = MIN_CHARACTER_AGE; i <= MAX_CHARACTER_AGE; i++) {
        format(menu, sizeof (menu), "%s%i\n", menu, i);
    }

    strcat(menu, "Other");

    ShowPlayerDialog(playerid, DIALOG_CHARACTER_AGE_CREATION, DIALOG_STYLE_TABLIST_HEADERS, "Character Age", menu, "Next", "Back");
}

static SelectCharacterSkinDialog(playerid) {
    new
        menu[128] = "Select your character's skin:\n"
    ;

    for (new i, size = sizeof (characterDefaultSkinList); i < size; i++) {
        format(menu, sizeof (menu), "%s%s: %i\n", menu, characterDefaultSkinList[i][0] ? "Female" : "Male", characterDefaultSkinList[i][1]);
    }

    ShowPlayerDialog(playerid, DIALOG_CHARACTER_SKIN_CREATION, DIALOG_STYLE_TABLIST_HEADERS, "Character Skin", menu, "Finish", "Back");
}

static ShowCharacterActionDialog(playerid, slotid) {
    new
        caption[16 + MAX_PLAYER_NAME]
    ;

    strcat(caption, "Character: ");
    strcat(caption, character[playerid][slotid][E_CHARACTER_NAME]);

    ShowPlayerDialog(playerid, DIALOG_CHARACTER_ACTION, DIALOG_STYLE_TABLIST_HEADERS, caption,
        "Select an action for the character:\nEnter with character\nDelete character",
        "Select", "Back"
    );
}

static SetCharacterSpawn(playerid, slotid, skinid, Float:x, Float:y, Float:z, Float:a) {
    TogglePlayerSpectating(playerid, false);
    SetSpawnInfo(playerid, NO_TEAM, skinid, x, y, z, a);
    SetPlayerName(playerid, character[playerid][slotid][E_CHARACTER_NAME]);
    SetCameraBehindPlayer(playerid);
    SpawnPlayer(playerid);

    playerIsLogged{playerid} = true;
    playerSelectCharacterSlotID{playerid} = slotid;

    CallLocalFunction("OnCharacterSpawn", "i", playerid);
}

static SavePlayerData(playerid) {
    if (!playerIsLogged{playerid}) {
        return;   
    }

    new const
        slotid = playerSelectCharacterSlotID{playerid}
    ;

    new
        data[E_CHARACTER_LOAD_DATA],
        query[1024]
    ;

    GetPlayerPos(playerid, data[E_CHARACTER_X], data[E_CHARACTER_Y], data[E_CHARACTER_Z]);
    GetPlayerFacingAngle(playerid, data[E_CHARACTER_A]);
    GetPlayerHealth(playerid, data[E_CHARACTER_HEALTH]);
    GetPlayerArmour(playerid, data[E_CHARACTER_ARMOUR]);

    mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "\
        UPDATE \
            `characters` \
        SET \
            `money` = %i, \
            `score` = %i, \
            `skin` = %i, \
            `world` = %i, \
            `interior` = %i, \
            `wanted` = %i, \
            `health` = %f, \
            `armour` = %f, \
            `x` = %f, \
            `y` = %f, \
            `z` = %f, \
            `a` = %f \
        WHERE \
            `id` = %i;",
        GetPlayerMoney(playerid),
        GetPlayerScore(playerid),
        GetPlayerSkin(playerid),
        GetPlayerVirtualWorld(playerid),
        GetPlayerInterior(playerid),
        GetPlayerWantedLevel(playerid),
        data[E_CHARACTER_HEALTH],
        data[E_CHARACTER_ARMOUR],
        data[E_CHARACTER_X],
        data[E_CHARACTER_Y],
        data[E_CHARACTER_Z],
        data[E_CHARACTER_A],
        _:character[playerid][slotid][E_CHARACTER_DATABASE_ID]
    );

    mysql_tquery(MYSQL_DEFAULT_HANDLE, query);

    ResetPlayerData(playerid);

    CallLocalFunction("OnCharacterLogOut", "i", playerid);
}

static ResetPlayerData(playerid) {
    static const
        CHARACTER_DATA_CLEAN[E_CHARACTER_DATA]
    ;

    for (new i; i < MAX_ACCOUNT_CHARACTERS; i++) {
        character[playerid][i] = CHARACTER_DATA_CLEAN;
    }

    Iter_Clear(PlayerCharacter[playerid]);

    playerIsLogged{playerid} = false;
}

/**
 * # External
 */

stock SetCharacterDatabaseID(playerid, slotid, DBID:id) {
    character[playerid][slotid][E_CHARACTER_DATABASE_ID] = id;
}

stock DBID:GetCharacterDatabaseID(playerid, slotid) {
    return character[playerid][slotid][E_CHARACTER_DATABASE_ID];
}

stock SetCharacterName(playerid, slotid, const name[]) {
    format(character[playerid][slotid][E_CHARACTER_NAME], _, name);
}

stock GetCharacterName(playerid, slotid, name[], size = sizeof (name)) {
    format(name, size, character[playerid][slotid][E_CHARACTER_NAME]);
}

/**
 * # Hooks
 */

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    switch (dialogid) {
        case DIALOG_CHARACTER_SELECTION: {
            if (!response) {
                DelayedKick(playerid, "Decided to leave");

                return 1;
            }

            if (!Iter_Contains(PlayerCharacter[playerid], listitem)) {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_NAME_CREATION, DIALOG_STYLE_INPUT, "Character Creation",
                    "{FFFFFF}Ok {98FB98}%s{FFFFFF},\n{FFFFFF}Choose a name to create a new character:",
                    "Next", "Back", ReturnPlayerName(playerid)
                );

                return 1;
            }

            playerSelectCharacterSlotID{playerid} = listitem;

            ShowCharacterActionDialog(playerid, listitem);
        }

        case DIALOG_CHARACTER_ACTION: {
            if (!response) {
                ShowCreateCharacterDialog(playerid);

                return 1;
            }

            new const
                slotid = playerSelectCharacterSlotID{playerid}
            ;

            switch (listitem) {
                case 0: {
                    new
                        query[64]
                    ;

                    mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "SELECT * FROM `characters` WHERE `id` = %i;", _:character[playerid][slotid][E_CHARACTER_DATABASE_ID]);
                    mysql_tquery(MYSQL_DEFAULT_HANDLE, query, "OnCharacterRetrieve", "ii", playerid, slotid);
                }

                case 1: {
                    ShowPlayerDialog(playerid, DIALOG_CHARACTER_CONFIRM_DELETE, DIALOG_STYLE_INPUT, "Delete Character",
                        "{FFFFFF}Please write the character name (%s) below to confirm the deletion:",
                        "Submit", "Back", character[playerid][slotid][E_CHARACTER_NAME]
                    );
                }
            }
        }

        case DIALOG_CHARACTER_CONFIRM_DELETE: {
            if (!response) {
                ShowCharacterActionDialog(playerid, playerSelectCharacterSlotID{playerid});

                return 1;
            }

            new const
                slotid = playerSelectCharacterSlotID{playerid}
            ;

            if (strcmp(inputtext, character[playerid][slotid][E_CHARACTER_NAME])) {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_CONFIRM_DELETE, DIALOG_STYLE_INPUT, "Delete Character",
                    "{FFFFFF}Please write the character name (%s) below to confirm the deletion:\n\n{FF0000}Wrong name.",
                    "Submit", "Back", character[playerid][slotid][E_CHARACTER_NAME]
                );

                return 1;
            }

            new const
                DBID:id = character[playerid][slotid][E_CHARACTER_DATABASE_ID]
            ;

            character[playerid][slotid][E_CHARACTER_DATABASE_ID] = INVALID_DATABASE_ID;
            character[playerid][slotid][E_CHARACTER_NAME][0] = EOS;

            Iter_Remove(PlayerCharacter[playerid], slotid);

            ShowCreateCharacterDialog(playerid);

            new
                query[64]
            ;

            mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "DELETE FROM `characters` WHERE `id` = %i;", _:id);
            mysql_tquery(MYSQL_DEFAULT_HANDLE, query);
        }

        case DIALOG_CHARACTER_NAME_CREATION: {
            if (!response) {
                ShowCreateCharacterDialog(playerid);

                return 1;
            }

            if (!(3 <= strlen(inputtext) <= MAX_PLAYER_NAME)) {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_NAME_CREATION, DIALOG_STYLE_INPUT, "Character Creation",
                    "{FFFFFF}Ok {98FB98}%s{FFFFFF},\n{FFFFFF}Choose a name to create a new character:\n\n{FF0000}Enter a name between 3 to %i characters.",
                    "Next", "Back", ReturnPlayerName(playerid), MAX_PLAYER_NAME
                );

                return 1;
            }

            new
                query[128]
            ;

            mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "SELECT `id` FROM `characters` WHERE `name` = '%e' LIMIT 1;", inputtext);
            mysql_tquery(MYSQL_DEFAULT_HANDLE, query, "OnCharacterNameCheck", "is", playerid, inputtext);
        }
    
        case DIALOG_CHARACTER_GENDER_CREATION: {
            if (!response) {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_NAME_CREATION, DIALOG_STYLE_INPUT, "Character Creation",
                    "{FFFFFF}Ok {98FB98}%s{FFFFFF},\n{FFFFFF}Choose a name to create a new character:",
                    "Next", "Back", ReturnPlayerName(playerid)
                );

                return 1;
            }

            playerSelectCharacterGender{playerid} = listitem;

            SelectCharacterAgeDialog(playerid);
        }

        case DIALOG_CHARACTER_AGE_CREATION: {
            if (!response) {
                ShowPlayerDialog(playerid, DIALOG_CHARACTER_GENDER_CREATION, DIALOG_STYLE_TABLIST_HEADERS, "Character Gender",
                    "Select your character's gender:\nMale\nFemale\nNeutral",
                    "Next", "Back"
                );
                
                return 1;
            }

            playerSelectCharacterAge{playerid} = (MIN_CHARACTER_AGE + listitem);

            SelectCharacterSkinDialog(playerid);
        }

        case DIALOG_CHARACTER_SKIN_CREATION: {
            if (!response) {
                SelectCharacterAgeDialog(playerid);
                
                return 1;
            }

            new const
                slotid = playerSelectCharacterSlotID{playerid}
            ;

            playerSelectCharacterSkin[playerid] = characterDefaultSkinList[listitem][1];

            new
                query[256]
            ;

            mysql_format(MYSQL_DEFAULT_HANDLE, query, sizeof (query), "INSERT INTO `characters` (`account_id`, `name`, `gender`, `age`, `skin`) VALUES (%i, '%e', %i, %i, %i);", _:GetAccountDatabaseID(playerid), character[playerid][slotid][E_CHARACTER_NAME], playerSelectCharacterGender{playerid}, playerSelectCharacterAge{playerid}, playerSelectCharacterSkin[playerid]);
            mysql_tquery(MYSQL_DEFAULT_HANDLE, query, "OnCharacterInsertDatabase", "ii", playerid, slotid);
        }
    }

    return 1;
}

hook OnPlayerLogIn(playerid) {
    CheckCharacterDatabase(playerid);
    
    return 1;
}

hook OnPlayerRegister(playerid) {
    CheckCharacterDatabase(playerid);
    
    return 1;
}

hook OnPlayerDisconnect(playerid, reason) {
    SavePlayerData(playerid);

    return 1;
}

/**
 * # Calls
 */

public OnCharacterCheck(playerid) {
    new const
        rows = cache_num_rows()
    ;

    for (new i; i < rows; i++) {
        cache_get_value_int(i, "id", _:character[playerid][i][E_CHARACTER_DATABASE_ID]);
        cache_get_value(i, "name", character[playerid][i][E_CHARACTER_NAME]);

        Iter_Add(PlayerCharacter[playerid], i);
    }

    ShowCreateCharacterDialog(playerid);

    return 1;
}

public OnCharacterNameCheck(playerid, const name[]) {
    if (cache_num_rows()) {
        ShowPlayerDialog(playerid, DIALOG_CHARACTER_NAME_CREATION, DIALOG_STYLE_INPUT, "Character Creation",
            "{FFFFFF}Ok {98FB98}%s{FFFFFF},\n{FFFFFF}Choose a name to create a new character:\n\n{FF0000}This name (%s) already exists, enter another name.",
            "Next", "Back", ReturnPlayerName(playerid), name
        );

        return 1;
    }

    new const
        slotid = Iter_Free(PlayerCharacter[playerid])
    ;

    format(character[playerid][slotid][E_CHARACTER_NAME], _, name);

    playerSelectCharacterSlotID{playerid} = slotid;

    ShowPlayerDialog(playerid, DIALOG_CHARACTER_GENDER_CREATION, DIALOG_STYLE_TABLIST_HEADERS, "Character Gender",
        "Select your character's gender:\nMale\nFemale\nNeutral",
        "Next", "Back"
    );

    return 1;
}

public OnCharacterInsertDatabase(playerid, slotid) {
    character[playerid][slotid][E_CHARACTER_DATABASE_ID] = DBID:cache_insert_id();

    SetCharacterSpawn(
        playerid,
        slotid,
        playerSelectCharacterSkin[playerid],
        DEFAULT_SPAWN_X,
        DEFAULT_SPAWN_Y,
        DEFAULT_SPAWN_Z,
        DEFAULT_SPAWN_A
    );

    Iter_Add(PlayerCharacter[playerid], slotid);

    return 1;
}

public OnCharacterRetrieve(playerid, slotid) {
    new
        data[E_CHARACTER_LOAD_DATA]
    ;

    cache_get_value_int(0, "money", data[E_CHARACTER_MONEY]);
    cache_get_value_int(0, "score", data[E_CHARACTER_SCORE]);
    cache_get_value_int(0, "skin", data[E_CHARACTER_SKIN_ID]);
    cache_get_value_int(0, "world", data[E_CHARACTER_WORLD_ID]);
    cache_get_value_int(0, "interior", data[E_CHARACTER_INTERIOR_ID]);
    cache_get_value_int(0, "wanted", data[E_CHARACTER_WANTED]);
    cache_get_value_float(0, "health", data[E_CHARACTER_HEALTH]);
    cache_get_value_float(0, "armour", data[E_CHARACTER_ARMOUR]);
    cache_get_value_float(0, "x", data[E_CHARACTER_X]);
    cache_get_value_float(0, "y", data[E_CHARACTER_Y]);
    cache_get_value_float(0, "z", data[E_CHARACTER_Z]);
    cache_get_value_float(0, "a", data[E_CHARACTER_A]);

    GivePlayerMoney(playerid, data[E_CHARACTER_MONEY]);
    SetPlayerScore(playerid, data[E_CHARACTER_SCORE]);
    SetPlayerVirtualWorld(playerid, data[E_CHARACTER_WORLD_ID]);
    SetPlayerInterior(playerid, data[E_CHARACTER_INTERIOR_ID]);
    SetPlayerWantedLevel(playerid, data[E_CHARACTER_WANTED]);
    SetPlayerHealth(playerid, data[E_CHARACTER_HEALTH]);
    SetPlayerArmour(playerid, data[E_CHARACTER_ARMOUR]);

    SetCharacterSpawn(
        playerid,
        slotid,
        data[E_CHARACTER_SKIN_ID],
        data[E_CHARACTER_X],
        data[E_CHARACTER_Y],
        data[E_CHARACTER_Z],
        data[E_CHARACTER_A]
    );

    return 1;
}
