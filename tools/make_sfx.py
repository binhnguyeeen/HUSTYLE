# Writes the sound effects as small WAV files. Run: python3 tools/make_sfx.py
import math, random, struct, wave

RATE = 44100


def save(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open("assets/sfx/%s.wav" % name, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.8 * 32767)) for s in samples))


def tone(freq, seconds, decay, end_freq=None):
    out, phase = [], 0.0
    n = int(RATE * seconds)
    for i in range(n):
        t = i / n
        f = freq + ((end_freq or freq) - freq) * t
        phase += 2 * math.pi * f / RATE
        env = math.exp(-decay * t) * min(1.0, i / (RATE * 0.004))
        out.append((math.sin(phase) + 0.3 * math.sin(2 * phase)) * env)
    return out


def mix(a, b, offset=0.0):
    start = int(offset * RATE)
    out = a + [0.0] * max(0, start + len(b) - len(a))
    for i, s in enumerate(b):
        out[start + i] += s
    return out


# Buy: two quick rising notes.
save("buy", mix(tone(660, 0.07, 3), tone(990, 0.14, 5), 0.06))
# Sell: a bright coin ping.
save("sell", mix(tone(1175, 0.08, 4), tone(1568, 0.3, 6), 0.05))
# Crash: a falling low sweep with a burst of noise.
random.seed(7)
noise, last = [], 0.0
for i in range(int(RATE * 0.5)):
    last = last * 0.92 + random.uniform(-1, 1) * 0.08
    noise.append(last * 6 * math.exp(-7 * i / (RATE * 0.5)))
save("crash", mix(tone(240, 0.8, 3, 45), noise))
# Spike: a fast rising sweep.
save("spike", mix(tone(440, 0.3, 2, 1320), tone(1760, 0.2, 6), 0.26))
