<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-brand-logo-dark.png">
    <img src="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-brand-logo-light.png" alt="MaiPai" width="420">
  </picture>
</p>

<p align="center"><i>say it like "my pie"</i></p>

<h3 align="center">Private, local AI that's actually yours.</h3>

<p align="center"><a href="https://getmaipai.github.io/"><b>getmaipai.github.io</b></a></p>

<p align="center">
Your own AI at home, a robot companion, and apps to reach them anywhere, all on your own hardware, never the cloud.
</p>

---

<table>
  <tr>
    <td align="center" width="120">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-home-icon-dark.png">
        <img src="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-home-icon-light.png" alt="MaiPai Home" width="72">
      </picture>
    </td>
    <td><b><a href="https://github.com/getmaipai/home">MaiPai Home</a></b><br>Your own AI, music, videos, podcasts, maps, books, and more, on your own hardware, online or offline - for protection, privacy, and independence.</td>
  </tr>
  <tr>
    <td align="center">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-desktop-icon-dark.png">
        <img src="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-desktop-icon-light.png" alt="MaiPai Desktop" width="72">
      </picture>
    </td>
    <td><b>MaiPai Desktop</b><br>Mac and Windows app for your MaiPai Home and Bot, right on your desktop, integrated with your dock and your computer.</td>
  </tr>
  <tr>
    <td align="center">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-go-icon-dark.png">
        <img src="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-go-icon-light.png" alt="MaiPai Go" width="72">
      </picture>
    </td>
    <td><b>MaiPai Go</b><br>iPhone and Apple TV app for your MaiPai Home and Bot: your own AI, media, and robot companion, wherever you are.</td>
  </tr>
  <tr>
    <td align="center">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-bot-icon-dark.png">
        <img src="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-bot-icon-light.png" alt="MaiPai Bot" width="72">
      </picture>
    </td>
    <td><b>MaiPai Bot</b><br>A robot friend with its own onboard AI: it sees, hears, talks, thinks, moves, self-charges, and guards your home in sentry mode. It recognizes each person by face and voice, keeps its own memories of people, facts, and experiences, and learns and evolves with your family.</td>
  </tr>
</table>

<table>
  <tr>
    <td align="center" width="120">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-stack-icon-dark.png">
        <img src="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-stack-icon-light.png" alt="MaiPai Stack" width="72">
      </picture>
    </td>
    <td><b><a href="https://github.com/getmaipai/stack">MaiPai Stack</a></b><br>The easy way to run your own local AI: the whole stack installed, watched, tested and kept up to date on your own computer, for you and anything you build on it.</td>
  </tr>
  <tr>
    <td align="center">
      <img src="https://raw.githubusercontent.com/getmaipai/.github/main/brand/maipai-brand-icon.png" alt="MaiPai Catalog" width="72">
    </td>
    <td><b><a href="https://github.com/getmaipai/catalog">MaiPai Catalog</a></b><br>Every plugin, app, companion, integration, and model for your hub and robot, in one signed catalog you review and install with one click.</td>
  </tr>
</table>

## How it fits together

Six pieces, one house. Everything runs on your own hardware, and the
layers only talk to each other inside your home.

```mermaid
flowchart TB
  subgraph reach["Reach it"]
    go["MaiPai Go<br/>iPhone and Apple TV"]
    desktop["MaiPai Desktop<br/>Mac and Windows"]
    browser["Any browser<br/>on your home network"]
  end
  subgraph house["Your home"]
    home["MaiPai Home<br/>the hub: your family, memory,<br/>companions and apps, kid-safe profiles"]
    bot["MaiPai Bot<br/>the robot: pairs with Home when near,<br/>complete on its own when not"]
  end
  subgraph ai["The AI itself"]
    stack["MaiPai Stack<br/>the engines and models,<br/>on your computer"]
    stack2["MaiPai Stack<br/>a smaller one<br/>on board the robot"]
  end
  catalog["MaiPai Catalog<br/>plugins, apps, companions, voices and models, signed and reviewed"]
  go --> home
  desktop --> home
  browser --> home
  go -.-> bot
  home <-.->|pairs| bot
  home --> stack
  bot --> stack2
  catalog --> home
  catalog --> bot
  catalog --> stack
```

- **The Stack** runs the AI: it installs the engines and models, sizes
  them to your computer, and keeps them healthy. You can run it by
  itself.
- **Home** sits on top and adds the people: profiles, memory,
  companions, apps, and the rules for kids.
- **Bot** carries its own Stack and its own copy of Home's brain, so it
  works alone and joins the family when it is in range.
- **Go and Desktop** are how you reach Home and Bot from a phone, a TV
  or a computer. They never talk to the Stack directly.
- **The Catalog** is where everything installable comes from, reviewed
  and signed, added with one click.

<p>Built and maintained by <a href="https://github.com/JesseWebDotCom">Jesse Torres</a>.</p>
