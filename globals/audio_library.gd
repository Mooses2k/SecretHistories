extends Node
##Generic autoload, to be used as central location to grab any sound collections that are used by many objects. 
##Loading only once, it helps not access the disk every time an object using them is spawned

enum AUDIO_TYPE {
	FOOTSTEPS,
	CULTIST_VOICES,
	PLAYER_VOICES
}


##Add more types as required
enum FOOTSTEP_TYPES{
	STONE,
	GRAVEL,
	CARPET
}
	
enum CULTIST_VOICE_TYPE {
	IDLE,
	ALERT,
	DETECTION,
	AMBUSH,
	CHASE,
	FIGHT,
	RELOAD,
	FLEE,
	DIALOG_Q,
	DIALOG_A,
	DIALOG_SEQUENCE,
	SURPRISED,
	FIRE,
	SNAKE,
	BOMB,
	COMET
}


##Add more, as they become available
var library:Dictionary = {
	##Structure: library[AUDIO_TYPE][Optional subtype] = [list of audio streams]
	AUDIO_TYPE.FOOTSTEPS: {
		FOOTSTEP_TYPES.STONE: [
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_1.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_2.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_3.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_4.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_5.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/stone_footsteps/footstep_6.wav") as AudioStream
		],
		FOOTSTEP_TYPES.GRAVEL: [
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel1.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel2.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel3.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel4.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel5.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/gravel_footsteps/footsteps_gravel6.wav") as AudioStream
		],
		FOOTSTEP_TYPES.CARPET: [
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet1.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet2.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet3.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet4.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet5.wav") as AudioStream,
			preload("res://resources/sounds/footsteps/carpet_footsteps/footsteps_carpet6.wav") as AudioStream
		]
	},
	
	AUDIO_TYPE.CULTIST_VOICES: {
		CULTIST_VOICE_TYPE.ALERT: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteBrother.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteFather.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteFinally.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteFive.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteHmm.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteIKnowYoureThereBrother.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteIKnowYoureThereSister.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteIsItRatsies.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteItBegins.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteMummy.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteOiWhosThatThen.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteProbablyJustRats.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteQuitTaffinAbout.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteRatsAgain.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteSister.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteSomeoneHidingThere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteSomeoneTaffinAboutOverThere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteSomeoneHidingThere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteSomethingsWrongHere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteUnusuallyLargeRats.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteWhatsThat.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteWhoGoesThere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteWhosTaffinAround.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/NeophyteWhosThere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/neophyte_r_oi_whos_that_then.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/neophyte_r_somethings_wrong_here_1.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/neophyte_r_somethings_wrong_here_2.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/neophyte_r_somethings_wrong_here_3.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/neophyte_r_whos_that_taffin_around_1.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/alert/neophyte_r_whos_that_taffin_around_2.ogg") as AudioStream,
		],
		
		CULTIST_VOICE_TYPE.AMBUSH: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/ambush/NeophyteCanHeHearUsShhh.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/ambush/NeophyteHehehehehe.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/ambush/NeophyteHesAlmostHere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/ambush/NeophyteIcanHearHim.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/ambush/NeophyteQuietDown.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/ambush/NeophyteShhHesComing.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/ambush/NeophyteSooooon.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/ambush/NeophyteThisIsGoingToBeARightProperAmbush.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/ambush/NeophyteYouKnowWhatToDo.wav") as AudioStream
		],
		
		CULTIST_VOICE_TYPE.BOMB: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/bomb/NeophyteABomb.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/bomb/NeophyteItsABomb.wav") as AudioStream,
		],
		
		CULTIST_VOICE_TYPE.COMET: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/comet/NeophyteAForeignAlienLight.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/comet/NeophyteByTheStars.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/comet/NeophyteINeedToTellSomeone.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/comet/NeophyteRideTheTailOfTheComet.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/comet/NeophyteStarsarePretty.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/comet/NeophyteTuneToMeCrystalRadio.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/comet/NeophyteTuningForkOfTheSoul.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/comet/neophyte_r_a_foreign_alien_light_2.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/comet/ride_the_tail_of_the_comet.ogg") as AudioStream,
		],
		
		CULTIST_VOICE_TYPE.DETECTION: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteAgentsOfTheCrown.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteAgentsOfTheReptileQueen.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteARat.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteDoYouFeelAVoidInYourLife.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteHehehHowCanYouEvenMoveLikeThat.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteIKnowYou.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteItsFinallyHere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteItsNotSupposedToBeOut.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteItsTheAnarchists.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteItsTheCavalry.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteItsTheMongols.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteItsThePigMother.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteItsTheTaxCollectors.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteItsTheUnionBusters.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteItWasRatsiesAfterAll.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteIveBeenWaitingForYou.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteLetsMakeSomeMemories.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteScotlandYard.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteTheSkyIsFalling.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteTheyreHere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteWhatAreYou.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteWhatsWrongWithYourEyes.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteWhoAreYou.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteWhoDoYouWorkFor.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteWhyAreYouHere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteYoureHere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteYourEyesAreWrong.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/NeophyteYourEyesBetrayYou.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/neophyte_r_he_found_me_1.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/neophyte_r_he_found_me_2.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/neophyte_r_he_found_me_3.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/neophyte_r_he_found_me_4.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/neophyte_r_he_found_me_5.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/neophyte_r_its_finally_here_1.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/detection/neophyte_r_its_finally_here_2.ogg") as AudioStream,
		],
		
		CULTIST_VOICE_TYPE.FIGHT: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteAllWillBeExplainedOnceYoureDead.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteChokeOnThis.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteDontMakeTheWrongTurnNow.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteDontTripNow.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteHaveATasteOfThis.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteHesHeadingTowardsADeadend.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteIfYourNotWithUsYouDontExist.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteIfYourNotWithUsYourAgainstUs.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteJustLetMeSlipThisBetweenYourRibs.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteJustOpenYourThroatAlready.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteNoEscape.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteSlowDown.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteTakethat.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteThisIsTakingTooLong.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteThisTooShallPass.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteWhereDoYouThinkYoureGoing.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteWhyYaRunnin.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteWouldYouPleaseJustDieForMe.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteYouCantEscape.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteYouHaveNoChanceToSurviveMakeYourTime.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteYoullBeFlungApartYoullSee.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteYourFateIsSealed.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteYourLifeLeavesYou.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fight/NeophyteYourMindWillBePulledOutLikeEyeballs.wav") as AudioStream,
		],
		
		CULTIST_VOICE_TYPE.FIRE: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fire/NeophyteArrrghItBurns.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fire/NeophyteFiiiire.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fire/NeophyteItBurnsx2.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fire/neophyte_r_argh_it_burns_1.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fire/neophyte_r_argh_it_burns_2.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fire/neophyte_r_argh_it_burns_3.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/fire/neophyte_r_argh_it_burns_4.ogg") as AudioStream,
		],
		
		CULTIST_VOICE_TYPE.FLEE: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteDeathNooo.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteI'mOut.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteIGiveUpDontFollowMe.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteIllTellTheOthers.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteIThinkILeftTheOvenOn.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteItsNotCowardiceIfILive.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteLetsParley.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteNoNoDontShootpleaseNoo.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteRepositioning.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteTakeThemNotMe.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteYouCantKillMe.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/flee/NeophyteYoullRueTheDay.wav") as AudioStream,
		],
		
		CULTIST_VOICE_TYPE.IDLE: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/everything_will_come_together.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/flesh_is_willing.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/hard_to_forget_someone.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/if_i_were_a_comet_fragment.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/if_i_were_the_one_to_discover_it_theyll_bathe_me_in_the_light.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/if_i_were_the_one_to_find_it.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/machine_elves.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteALightThatDiedIsShiningInTheWater.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteAllElectionsAreShams.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteAllHailTheEarthsSpiderKing.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteAtLeastImNotOnWiringDuty.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteClocksAndCalandersBallAndChain.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteDoesTheBlackMoonHowl.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteEverythingWillComeTogether.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteFuckItsFindingTheHoles.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteHmphPolitics.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteIDreamAboutGoingUpThere.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteIfIDiscoverItTheyllBatheMeInTheLight.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteIfIWereACometFragmentWhereWouldIBe.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteIfIWereTheOneToFindIt.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteIllRideTheTailOfTheCometOnceIFindIt.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteILoveHowTheWallsDontLineUpAnymore.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteImNoElectricityMan.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteImPrettySureThatWasntBeefInTheStewLastNight.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteINeededToDoThis.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteItsHardToForgetSomeone.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteIWonderWhatGreenSlimeTasteLike.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteIWonderWhatTheMachineElves.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteJoinTheCultTheySaidSeeTheWorldTheySaid.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteLetsMarchOnTheCapitolBuilding.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteLookMaNoEyes.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteMyMotherSaidIdNeverAmountToAnything.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteSeeTheWorldMeetInterestingPeople.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteSlowlyQuietly.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteSomewhereInTheHeavens.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteStarsDieInThrees.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteTheBlackDogRunsAtNight.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteTheDarkness.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteTheFleshIsWilling.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteTheOwlsAreNotWhatTheySeem.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteThePastIsNeverDead.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteTheRealityIs....wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteThereIsOnlyTheStarfish.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteTheStillQuietLightOfTheStars.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteTheWayThatCanBeKnownIsNotTheTrueWay.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteTheyreAllSmarterThanIAm.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteThisIsMyHoleItWasMadeForMe.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteUnderTheSeaOutInFarspace.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteWhatAmIDoingInAGraveYard....wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteWhatAmIDoingInThisSmellySewer.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteWhatWereWeTalkingAbout.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteWhereAreYouHidingPreciousSkyCrystal.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteWhereAreYouSongHum.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteWhereIsIt.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteWhyDoIHaveAGunInMyHand.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/NeophyteYouHaveToKeepCalm.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/neophyte_r_a_light_that_died_is_shining_in_the_water_1.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/neophyte_r_a_light_that_died_is_shining_in_the_water_2.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/neophyte_r_a_light_that_died_is_shining_in_the_water_4.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/neophyte_r_stars_may_die_in_threes_2.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/neophyte_r_stars_may_die_in_threes_3.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/neophyte_r_stars_may_die_in_threes_5.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/neophyte_r_still_quiet_light.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/past_is_never_dead.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/slowly_quietly.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/somewhere_in_the_heavens.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/stars_may_die_in_threes.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/the_owls_are_not_what_they_seem.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/the_reality_is.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/the_way_that_can_be_known_is_not_the_true_way.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/tune_to_me_crystal_radio.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/tuning_fork_of_the_soul.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/where_are_you_1.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/where_are_you_2.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/where_are_you_3.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/where_are_you_hiding_precious_sky_crystal.ogg") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/idle/where_is_it.ogg") as AudioStream,
		],
		
		CULTIST_VOICE_TYPE.SNAKE: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/snake/NeophyteSnaaakes.wav") as AudioStream,
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/snake/NeophyteWhydItHadToBeSnakes.wav") as AudioStream,
		],
		
		CULTIST_VOICE_TYPE.SURPRISED: [
			preload("res://resources/sounds/voices/cultists/neophyte/deanbrignell/surprised/NeophyteBloodyHellx3.wav") as AudioStream,
		]
	}
}

func get_footsteps(material: FOOTSTEP_TYPES) -> Array:
	##Add more methods like this, as more audio types are added to this file
	##If there is no subtype, don't add it
	##Alternative if memory usage at start is in question, lazy loading version:
	##    get_<audio type>(<optional subtype>: <subtype enum>):
	##        if (library[<audio type>] == null):
	##            library[<audio type>] = <if using subtypes, {}, otherwise, []>
	##        if (library[<audio type>][<optional subtype> == null or library[<audio type>][<optional subtype>].is_empty()):
	##            library[<audio type>][<optional subtype>] = []
	##            library[<audio type>][<optional subtype>].append(load("res://resources/sounds/<audio type>/<optional subtype>/file1.extension"))
	##            library[<audio type>][<optional subtype>].append(load("res://resources/sounds/<audio type>/<optional subtype>/file2.extension"))
	##            etc
	##        return library[<audio type>][<optional subtype>]
	return library[AUDIO_TYPE.FOOTSTEPS][material]


func get_voicelines(voice_tag: CULTIST_VOICE_TYPE) -> Array:
	return library[AUDIO_TYPE.CULTIST_VOICES][voice_tag]
