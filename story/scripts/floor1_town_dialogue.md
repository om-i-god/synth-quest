================================================================
            SYNTH QUEST — FLOOR 1 / VILLAGE CLEARING
                       NPC Dialogue Script
================================================================

Setting: the Village Clearing (per Dossier §LOCATIONS). A small
settlement around a stone inn, paths through trees, a southern
river, a cave entrance pulsing faintly to the east.

NPCs covered:
   - ELDER       (canon, Dossier)
   - LYRIK       (canon, Dossier)
   - HARROW      (innkeeper)            (new)
   - WIN         (child)                (new)
   - TILLA       (child)                (new)
   - SOREN       (lutemaker, flavor)    (new)

Line constraints: each line <= ~80 chars, max 3 lines per box.
Cadence: slightly antique. No modern idiom. Read aloud before keeping.


================================================================


## NPC: Elder

**Role:** Village elder. Living memory. The first voice to name
the threat.
**Location:** Standing by the well at the centre of the clearing,
between the inn and the eastern path.
**Voice/timbre:** Low, slow triangle hum. Long release.
**Ambient cue:** A soft pad in Lydian, faint, audible only when
the player stands close.


### First interaction

Stranger. You have a traveller's walk and a worried face.
That is two of the three things I look for.

The third thing is whether your eyes go east when I say "the cave."

Mine did, when I was your age. They still do.


### Repeat interaction (no quest active)

The well is good water. Drink before you go east.

I have lived through three quiet ages of this world.
I would prefer not to live through a fourth.

A friend of mine once said: a song is a kind of map.
I did not believe him then.


### Quest hook

**Quest title:** THE SHARD IN THE EASTERN CAVE
**Trigger:** First conversation with Elder, after the player
has spoken to at least one other NPC.

[ask]
There is a shard sleeping in the cave east of here.
It has slept a long time. I think it will not sleep much longer.

If you go to it — and someone will, soon — bring it back to me.
I would like to hold a piece of the world before I go.

[accept]
Good. The path is the path. The cave is the cave.
Walk softly when you reach it. The thing that guards it
is older than I am, and that is saying something.

[decline]
Then walk east anyway. You will see what I mean.
Come back when you are ready.


### Quest progress

Still east, friend. The cave is not coy. It is only deep.

I sleep less, these days. I am listening for something.
You will know it when it changes.


### Quest complete

(triggered: party returns with the LYDIAN shard)

You brought it.
You brought it back.

Set it down, gently. It is older than any of us
and it has been carried far.

(beat)

Listen. Listen. Yes — the air is steadier already.
This is what the world used to feel like.
You have given me an evening I did not expect to have.

[reward / parting]
Take this. A small thing. It belonged to a friend
who would rather you had it than I did.
   >> RECEIVED: Old Tuning Fork (relic, +1 MAG party-wide)

Five shards still sleep, somewhere in the world.
You will find them, or someone will.
Either way, this old man thanks you.


================================================================


## NPC: Lyrik

**Role:** Wandering musician/historian. Sings the old chronicles.
Claims to remember the Held Chord.
**Location:** Sitting on the low stone wall by the inn, lute
across her knees, watching the path.
**Voice/timbre:** Mid-bright sawtooth, gently filtered. Warm.
**Ambient cue:** A faint plucked motif when approached — a
fragment of a chronicle she is trying to remember.


### First interaction

Sit, if you like. The wall is warm and I have been alone with it
all morning.

I sing the old chronicles. Most of them are wrong, now.
The right parts are the parts that nobody remembers.

You have not heard the Held Chord. Neither have I, properly.
But I remember its shape, the way you remember a dream.


### Repeat interaction (no quest active)

The bard is rehearsing inside. He is better than he thinks.

Old songs travel. New ones stay home.
I do not know which kind I am.

If you walk east, listen for the under-pitch.
The world's bottom note has gone soft there.


### Quest hook

**Quest title:** THE LOST VERSE
**Trigger:** Talk to Lyrik twice; on the second visit she asks.

[ask]
There is a verse I have lost.
A traveller's verse — five lines, a Lydian verse.
A man I once shared a kettle with sang it. He did not write it down.

He died last winter. The verse with him.
Unless the cave remembers it. The cave remembers most things.

If you find anything down there — anything sung —
bring it to me. Even a fragment. Even a phrase.

[accept]
Thank you. I will be here.
The wall is warm and I am patient.

[decline]
That is fair. It is an old man's grief and not yours.
Sit a while anyway, if you like.


### Quest progress

Still east. Still listening.

If you hear five lines together, that will be it.


### Quest complete

(triggered: player returns with the LYRIC FRAGMENT loot from
Cave 1, dropped by an optional MUSHROOM encounter)

You brought it.
Five lines? Five lines.

Wait. Let me — let me sing it back, carefully.

(she sings, or the player imagines her singing)

There. There he is. There he goes again.
He never could land that fourth line.

[reward / parting]
Take this. He gave it to me; I should not have kept it.
   >> RECEIVED: Singer's Quill (relic, +1 SPD party-wide)

Walk well. And if you find another verse in another cave,
bring it. I have a lot of friends in the ground.


### Post-Lydian-shard variation
(triggered after the LYDIAN shard is recovered, regardless of
side-quest state)

You feel it, do you not?

The air is steadier. The under-pitch has come back.
The wind in the eaves is settling onto its old root note.

I told you. The world is a song that has been
trying to remember itself.

Now there are six shards still sleeping.
I am not sure I will see them all returned.
But I will sit on this wall as long as the wall is warm.


================================================================


## NPC: Harrow

**Role:** Innkeeper. Keeps the stone building. Brisk, kind,
under-slept.
**Location:** Behind the counter inside the inn. (The door tile
in the stone building.)
**Voice/timbre:** Low square pulse, short envelope. Warm but
percussive.
**Ambient cue:** A low fire-crackle drone behind dialogue.


### First interaction

In, in. Door does that on its own — pretend it was you.

Bed's a copper a head, supper's two and bring your own cup.
Kettle's hot. The bard usually plays by the hearth after dark.

Walk in any time. Bed and a meal. The door knows you now.
   >> RESTING ENABLED at this inn (full HP/MP).


### Repeat interaction

In with you. Bed's where you left it.

Don't wake the bard. He's been writing.

Kettle's still hot. It always is. That's a kind of magic.


### Quest hook

**Quest title:** THE LULLABY THAT WON'T END
**Trigger:** Talk to Harrow once, then talk to Win or Tilla, then
return.

[ask]
The smaller one — Win — has been singing the same line
in her sleep for three nights.

It's an old lullaby. The end of it. Just the end.
Nobody alive knows the rest. She won't settle till someone does.

If you find anything in the cave that sounds like a beginning,
bring it. I'll stitch it onto the end and put her down proper.

[accept]
Thanks. Try not to wake her on the way past.

[decline]
Fair enough. I'll keep the kettle on.


### Quest progress

She's still humming it. I'm still tired.


### Quest complete

(triggered: player returns from Cave 1 with the BEGINNING-PHRASE
loot, dropped by the WISP encounter)

You hear it? Listen — that's the front of it.
Yes. That goes onto the back of the one she's been humming.

(beat)

Right then. Up you come, Win. I've got the whole song now.
Quiet, quiet, sleep, sleep —

[reward / parting]
She's down. First full night in a fortnight.
Take this. It was her grandfather's. He'd want it in moving hands.
   >> RECEIVED: Hearthstone Charm (accessory, +5 HP)

You're welcome here any time. Door knows you, now.


================================================================


## NPC: Win

**Role:** Child. Quiet, undersleeping, hums in her sleep.
**Location:** Sitting on the inn step, knees up, half-asleep.
**Voice/timbre:** A high triangle, very soft. Almost a whisper-
synth.
**Ambient cue:** A four-note hum on loop, slow.


### First interaction

(She is humming. She doesn't look up.)

Mm — mm-mm — mmmm.

(she notices you)

Oh. Hello. Sorry. I had a bit of a song stuck.
Harrow says it's the end of one. I don't know the front.

If you find the front, would you tell me?
I don't think I can sleep proper until I know how it starts.


### Repeat interaction

Mm-mm — mmmm.

Have you found it yet? The front?

I'm not tired. (she is very tired)


### Quest progress

Still stuck. Still humming. Sorry.


### Quest complete

(once Harrow has stitched the lullaby)

Oh. OH. That's how it goes.
That's how it goes. Of course.

(she yawns enormously)

Thanks. I'm going to — I'm going to —

(she is asleep)


================================================================


## NPC: Tilla

**Role:** Child. Loud. Unbothered. Holds a stick like it is a
sword.
**Location:** Running circuits between the well and the inn.
**Voice/timbre:** A bright square, fast. Short envelope.
**Ambient cue:** None — she is the cue.


### First interaction

You're new! Are you a hero? You look like one.
Win says heroes have a worried face. You have a worried face.

I have a sword. (it is a stick)
If a monster comes I'll get the first hit.

The bard's inside, the elder's at the well, Lyrik's on the wall.
That's the whole village except for Soren, who is boring.


### Repeat interaction

Still a hero?

Want to see my sword? (it is still a stick)

Win is asleep again. She is bad at being awake.


### Quest hook (mini)

**Quest title:** PIP THE CAT
**Trigger:** Talk to Tilla twice.

[ask]
My cat is missing. Her name is Pip.
She is grey and she is cross.

She likes the cave. I am not allowed in the cave.
You are bigger than me. You go.

[accept]
Bring her back. Don't let her bite you.
She bites.

[decline]
Fine. I will go myself when I am bigger.
I will be bigger soon.


### Quest progress

Pip is still gone. I am still cross. I am crosser than her.


### Quest complete

(triggered: player returns from Cave 1 with PIP — a small grey
cat sprite found near the cave's mouth)

PIP. PIP. You found her. You found her!

(she takes the cat. The cat looks unbothered.)

[reward / parting]
Here. You can have this. I don't need it. I have a sword.
   >> RECEIVED: Wooden Whistle (consumable, calls one Resonance
      at half cost; one use)

You're definitely a hero. I was right.


================================================================


## NPC: Soren

**Role:** Lutemaker. Quiet. No quest. Pure flavor.
**Location:** Working under an awning by the river path, south
of the inn. A half-finished lute in his lap.
**Voice/timbre:** Mid-low sine, very steady.
**Ambient cue:** The faint sound of a single string being plucked,
tuned, plucked again, on a slow loop.


### First interaction

Hello. Mind the shavings.

I make lutes. Not many. One a season, if the wood agrees.
Your bard friend is playing one of mine.
He doesn't know it. The man he bought it from didn't either.

A lute remembers its maker. It does not need to tell anyone.


### Repeat interaction (rotating)

Wood's quiet today. Won't sing till tomorrow.

Tilla calls me boring. She is correct.
Boring is what a lutemaker is paid to be.

The river is in tune with the inn's eaves.
I noticed this morning. I doubt anyone else has.


### Post-Lydian-shard variation

(no specific dialogue — but his ambient pluck is now in tune with
the Lydian drone, where before it was a shade flat. The player
who notices, notices.)


================================================================
                    END OF FLOOR 1 DIALOGUE
================================================================
