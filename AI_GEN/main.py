import torch
import torchaudio
import os
from zonos.model import Zonos
from zonos.conditioning import make_cond_dict

# Create output directories if they don't exist
os.makedirs("./AI_GEN/insult", exist_ok=True)
os.makedirs("./AI_GEN", exist_ok=True)

# Initialize model
model = Zonos.from_pretrained("Zyphra/Zonos-v0.1-hybrid", device="cuda")

# Load speaker reference
wav, sampling_rate = torchaudio.load("assets/me.wav")
speaker = model.make_speaker_embedding(wav, sampling_rate)

def generate_wav(text, output_path):
    """Generate WAV file from text using Zonos model"""
    cond_dict = make_cond_dict(
        text=text,
        speaker=speaker,
        language="en-us"
    )
    conditioning = model.prepare_conditioning(cond_dict)
    codes = model.generate(conditioning)
    wavs = model.autoencoder.decode(codes).cpu()
    torchaudio.save(output_path, wavs[0], model.autoencoder.sampling_rate)
    print(f"Generated: {output_path}")

# List of insults
remaining_insults = [
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

# Generate insult WAV files
#for i, insult in enumerate(remaining_insults, 1):
#    output_path = f"./AI_GEN/insult/{i}.wav"
#    generate_wav(insult, output_path)

# Generate startup message
startup_message = "You can use the space key to flip gravity. Collect keys from each level. Collect 100 clover for an additional key."
generate_wav(startup_message, "./AI_GEN/start_up.wav")

# Generate clover message
#clover_message = "I see a new key! It spawned thanks to the 100 clover you collected!"
#generate_wav(clover_message, "./AI_GEN/100_clover.wav")

# Generate clover message
#clover_message = "I'm out of insults. You died so many times, I'm actually impressed."
#generate_wav(clover_message, "./AI_GEN/just_wow.wav")

print("All audio files have been generated!")
