# insults.gd
extends Resource

# You can preload this script by adding this line to your player script:
# const InsultsResource = preload("res://path_to/insults.gd")

var remaining_insults = [
	# Classic snarky observations
	"Congratulations on finding the ground! Very thoroughly, I might add.",
	"That was quite innovative. Never before have I seen anyone die quite like that.",
	"Oh look, you are doing an excellent impression of a pancake!",
	"Your coordination is truly remarkable. Remarkably bad, but remarkable nonetheless.",
	
	# Gaming references
	"Achievement unlocked: Finding Creative Ways to Become Not Alive!",
	"Game Over! Would you like to purchase the Basic Survival Skills DLC?",
	"Loading remaining brain cells... Error 404: None found.",
	"The respawn screen says hello. Again.",
	"Tutorial: How to Stay Alive (Page 1 of 1) - Do not do that.",
	
	# Playful mockery
	"Have you considered becoming a professional at falling?",
	"That was a perfect score for faceplanting. The judges are impressed!",
	"Good news: You discovered gravity! Bad news: It discovered you back.",
	"I would offer help, but you seem to need an entirely new everything.",
	"Wow, you really emphasize the mortality in immortality.",
	
	# Sarcastic comfort
	"That is one way to take a break, I suppose.",
	"The respawn button has been expecting you.",
	"There exist much easier ways to take a nap.",
	"Rest in pieces would be more accurate in this case.",
	"Should I call a doctor? Perhaps a magician?",
	
	# Educational mockery
	"Welcome to the world-famous How to Not Stay Alive masterclass!",
	"The lesson for today: Gravity equals 1, Player equals 0.",
	"Physics experiment successful! Falling does indeed cause damage.",
	"Breaking news: Local player discovers gravity, takes research too far.",
	"And for the next demonstration, watch how to fail spectacularly!",
	
	# Constructive criticism
	"That seems like quite a permanent solution to a temporary problem.",
	"Even rocks display better survival instincts.",
	"At least you are setting records in speed-dying!",
	"Let me guess - the ground requested a hug?",
	"Ah yes, the classic testing if respawn works strategy.",
	
	# Philosophical quips
	"To exist, or to not exist... you made that choice rather clear.",
	"When a player falls and a fairy watches, it definitely still counts.",
	"Some say existence is fleeting. You take that quite literally.",
	"Plot twist: The floor is actually not lava. But thanks for checking.",
	"Regarding the game of life and death, you chose... interestingly.",
	
	# Weather report style
	"The forecast today: Cloudy with occasional falling players!",
	"Local fairy reports unexpected player shower in the area.",
	"Breaking news: Gravity remains operational! More at 11.",
	"Current status: Temporarily impaired by basic physics.",
	
	# Restaurant reviews
	"Rating this death five out of seven - perfect score!",
	"Public review: Ground too solid, would not recommend.",
	"This performance gets two thumbs in various directions.",
	"Dining with the ground? The face-first special seems popular.",
	
	# Tech support
	"Have you attempted a complete system restart?",
	"Error 404: Basic survival skills not found.",
	"Task failed in the most successful way possible!",
	"Critical error in player dot executable - Reboot recommended."
]

func get_insult() -> String:
	if remaining_insults.is_empty():
		return "I'm out of insults. You died so many times, I'm actually impressed."
		
	# Pick a random index
	var index = randi() % remaining_insults.size()
	
	# Get the insult and remove it from the array
	var chosen_insult = remaining_insults[index]
	remaining_insults.remove_at(index)
	
	return chosen_insult
