# ⚡ Focusd

**A distraction blocker for Linux that actually works — built with Bash, iptables, and a little Codeforces pain.**

Most Linux website blockers don't work. You edit `/etc/hosts`, feel productive for five minutes, and then realize your browser completely ignores it because of **DNS-over-HTTPS (DoH)** or open HTTP/2 sockets. Or you install an Electron app that eats 400MB of RAM just to tell you not to open Reddit.

I built **Focusd** because I wanted something lightweight, native, and near impossible to casually bypass.

---

## 💡 What makes it different?

Instead of playing cat-and-mouse with hosts files or browser extensions, Focusd handles distractions at the OS and network level:

- **Network-level DNS sinkholing:** Reroutes all outbound port 53 traffic into an isolated, loopback-bound `dnsmasq` instance that resolves unauthorized domains to `0.0.0.0`.
- **DoH blocking:** Blocks encrypted DNS endpoints (Cloudflare, Google, Quad9, AdGuard, NextDNS, etc.) on both TCP and UDP (`443`/`80`) so browsers can't slip past the local resolver.
- **Socket reset:** Flushes active connection tracking tables (`conntrack -F`) and resets open web connections (`ss -K`) the second study mode turns on.
- **Process reaper:** Monitors and kills distracting desktop applications running in the background.
- **The Codeforces Gate ("Hardcore Mode"):** Need to quit early? You can't just click "Exit." Focusd pulls a random 800–900 rated problem from the Codeforces API, whitelists the site, and won't release your system until you submit an accepted (`OK`) solution.

---

## 🧠 How it works under the hood

```
               [ User Space App / Browser ]
                            │
       ┌────────────────────┴────────────────────┐
       │                                         │
 Outbound Port 53 DNS Queries              Web Traffic
       │                                         │
┌──────▼────────────────────────┐       ┌────────▼───────────────────────┐
│ iptables NAT (OUTPUT)         │       │ iptables FILTER (OUTPUT)       │
│ Redirects UID to 127.0.0.1:5354│      │ Drops UDP:443 (QUIC / DoH)     │
└──────┬────────────────────────┘       │ Drops known public DoH IPs     │
       │                                └────────────────────────────────┘
┌──────▼────────────────────────┐
│ dnsmasq (Isolated instance)   │
│ • address=/#/0.0.0.0          │
│ • Allowed websites -> 8.8.8.8 │
│ • Essential CDNs whitelisted  │
└───────────────────────────────┘
```

### A few neat engineering details:
- **No systemd collisions:** Uses `dnsmasq-base` purely for its binary rather than launching a full systemd resolver service, avoiding conflicts with Ubuntu's `systemd-resolved`.
- **The 60-second cache trick:** Browsers cache DNS responses locally. To stop you from spending the first minute of your break staring at broken pages, Focusd releases firewall restrictions 60 seconds *before* your work interval ends, letting the browser refresh stale `0.0.0.0` records naturally.
- **Scoped sudoers:** Instead of asking you to run random scripts with blanket `sudo`, the installer drops a single, tightly-scoped rule in `/etc/sudoers.d/focusd` covering only the exact system binaries needed (`iptables`, `dnsmasq`, `conntrack`, etc.), verified with `visudo`.

---

## 🚀 Quick Install

Run this in your terminal:

```bash
curl -sL https://raw.githubusercontent.com/TanavB/focusd/main/install.sh | bash
```

The script will:
1. Ask for `sudo` once to install dependencies (`jq`, `zenity`, `dnsmasq-base`, `iptables`, `conntrack`).
2. Set up the scoped sudoers policy.
3. Download the core scripts to `~/.local/share/focusd/`.
4. Put global shortcuts in `~/.local/bin/`.
5. Add desktop launchers so Focusd shows up in your application menu.

*(Make sure `~/.local/bin` is in your `$PATH`, which is default on most modern distros).*

---

## 🎮 How to use it

### From your Application Menu (GUI)
Just search for **Focusd** in your app drawer / GNOME launcher:
- **Focusd (Study Mode):** Starts your session (or prompts the Codeforces challenge to stop).
- **Focusd Configuration:** Opens the setup window to change blocked apps, allowed sites, and timers.
- **Focusd Statistics:** Shows a quick breakdown of everything blocked so far.

### From your Terminal (CLI)
```bash
focusd-toggle  # Start or stop study mode
focusd-config  # Open configuration dialog
focusd-stats   # View session distraction stats
```

---

## ⚙️ Configuration

Running `focusd-config` opens an interactive GUI where you can set:
- **Distracting Apps:** A checklist auto-populated by scanning your `.desktop` applications.
- **Whitelisted Sites:** Websites you actually need for work or study (common CDN infrastructure like GitHub, Google, MathJax, and KaTeX are pre-whitelisted).
- **Hardcore Mode:** A simple toggle to turn the Codeforces exit requirement on or off.
- **Timers:** Work intervals (30–120 min) and break intervals (5–60 min).

All configuration and logs are kept in plain text inside `~/.config/focusd/`.

---

## 🥊 Hardcore Mode in action

If you have Hardcore Mode turned on and try to bail on your study session early:

1. Focusd queries the Codeforces API and grabs a random problem rated 800–900.
2. It dynamically injects `codeforces.com` into the DNS sinkhole whitelist and opens the problem in your browser.
3. You can either solve it or hit **Reroll Problem** if you get something you really don't like.
4. Once you submit, hit **Verify**. Focusd checks your handle's latest submissions via the Codeforces API. When it sees `"verdict": "OK"`, study mode finally turns off.

---

## 📊 Session Stats

Every time a distracting application is closed or a blocked domain tries to resolve, Focusd logs the event. Running `focusd-stats` gives you a quick snapshot:

- Total distractions stopped
- Top blocked application
- Top blocked domain

---

## 🗑️ Uninstalling

If you ever want to get rid of it completely:

```bash
curl -sL https://raw.githubusercontent.com/TanavB/focusd/main/uninstall.sh | bash
```

This cleans up all binaries, desktop entries, temporary files, and `/etc/sudoers.d/focusd`, with an optional prompt to delete your logs and configuration.

---

## 📄 License

MIT. Feel free to fork, tweak, and use it however you like.