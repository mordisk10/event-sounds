# Marketplace release checklist

Everything needed to put a new version on the JetBrains Marketplace, in the
order it has to happen. Nothing here uploads anything by itself.

---

## 1. One-time setup

### Create a permanent token

1. Sign in at <https://plugins.jetbrains.com/> with the account that owns the plugin
2. Go to <https://plugins.jetbrains.com/author/me/tokens>
3. **New token** → name it `github-actions` → copy it once (it is shown a single time)

> A permanent token is not a password. It only grants plugin-upload rights, it can be
> revoked from that page at any time, and revoking it does not affect the account.
> Never paste the account password into this repository, a workflow, or a chat.

### Store it in the repository

**Settings → Secrets and variables → Actions → New repository secret**

| Field | Value |
|:--|:--|
| Name | `JETBRAINS_MARKETPLACE_TOKEN` |
| Secret | the token from the step above |

Once saved, GitHub masks the value everywhere — it cannot be read back out.

---

## 2. Before every release

- [ ] Bump `pluginVersion` in `gradle.properties`
- [ ] Move the `[Unreleased]` entries in `CHANGELOG.md` under the new version
- [ ] Mirror those entries into `<change-notes>` in `src/main/resources/META-INF/plugin.xml`
      — this block is what users read on the Marketplace listing
- [ ] Confirm `pluginSinceBuild` still matches the oldest IDE you intend to support
- [ ] Green build on `master`

---

## 3. Dry run

**Actions → Publish to Marketplace → Run workflow**

| Input | Value |
|:--|:--|
| Release channel | `eap` |
| Build and verify only | ✅ **checked** |

This runs the tests, validates the plugin, builds the zip and uploads it as a run
artifact — and stops there. Download that zip and install it locally
(**Settings → Plugins → ⚙ → Install Plugin from Disk**) to check the real thing
in a real IDE before anyone else sees it.

---

## 4. Publish

Same workflow, **Build and verify only unchecked**.

Pick the channel deliberately:

| Channel | Who receives it | Use it for |
|:--|:--|:--|
| `eap` | Only users who added the EAP repository URL | First run of any release, risky changes |
| `default` | Everyone, via the normal plugin browser | Versions you have already validated |

Publishing to `eap` first is strongly recommended — the Marketplace does not let
you unpublish a version, only supersede it with a newer one.

After the upload, JetBrains runs an automated review. A first-time listing is
checked by a human and can take a couple of business days; subsequent versions
are usually approved within minutes.

---

## 5. Listing assets

Managed at <https://plugins.jetbrains.com/plugin/29305-fancy-event-sounds/edit>,
not from this repository.

| Asset | Status | Where it comes from |
|:--|:--|:--|
| Plugin icon | ✅ In the repo | `src/main/resources/META-INF/pluginIcon.svg`, packaged automatically |
| Description | ✅ In the repo | `<description>` in `plugin.xml` |
| Change notes | ✅ In the repo | `<change-notes>` in `plugin.xml` |
| Screenshots | ⬜ **Needs a real IDE** | Uploaded by hand on the listing page |
| Tags / category | ⬜ Needs a decision | Suggested below |

### Screenshots — shot list

The Marketplace expects real captures of the plugin running. These have to be
taken from an actual IDE with the plugin installed; a mockup is not a substitute
and would misrepresent the product.

Recommended: **PNG, 1280×800 or larger, light theme first** (the listing thumbnail
crops the top-left area, so keep the subject there).

1. **The settings screen** — *Settings → Tools → Event Sounds*, both events enabled,
   one row pointing at a custom `.mp3` so the browse field reads as usable
2. **The run toolbar mid-run** — the run configuration dropdown and the Run button,
   with the console showing a finished process
3. **A failed run** — the console with the "Process finished with exit code 1" state,
   which is the moment the error sound exists for

### Suggested listing metadata

- **Category:** Tools Integration
- **Tags:** `sound`, `notifications`, `productivity`, `run configurations`, `feedback`
- **Short summary:** *Plays a sound when your run starts or fails to start, so you
  get feedback without watching the Run window.*

---

## 6. If a publish fails

| Message | Cause | Fix |
|:--|:--|:--|
| `JETBRAINS_MARKETPLACE_TOKEN is not set` | Secret missing or misnamed | Re-add it under Actions secrets with the exact name |
| `401 Unauthorized` | Token revoked or wrong account | Generate a new token and update the secret |
| `Plugin version X.Y.Z already exists` | Version not bumped | Raise `pluginVersion` in `gradle.properties` |
| `Plugin verification failed` | Structure or compatibility problem | Read the `verifyPlugin` output in the run log |
