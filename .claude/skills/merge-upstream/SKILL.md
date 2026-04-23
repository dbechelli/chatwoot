---
name: merge-upstream
description: Use this skill when pulling chatwoot upstream (chatwoot/chatwoot) into the fazer-ai fork, resolving merge conflicts, and validating the result. Covers direction choice, per-file decision framework (KC/AI/CO/delete), recurring patterns (SaveBang, signature architecture, schema.rb regen, WhatsApp service, installation_config), validation flow, and pre-commit/CI pitfalls specific to this repo. Trigger when the user asks to merge develop/main from chatwoot upstream, resolve merge conflicts on a merge branch, or bump the fork to a new chatwoot version.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# Merge upstream (chatwoot → fazer-ai fork)

The fazer-ai fork diverges from chatwoot upstream on real features (Baileys, Zapi, per-inbox signatures, scheduled messages, group conversations, internal chat). Every few releases we pull upstream in to stay current. This skill captures the recurring patterns and footguns so the next merge doesn't rediscover them from scratch.

## Direction of merge

Prefer **branch from our fork's `main`, merge `upstream/develop` into it**, not the other way around.

- Same number of conflicts either way — git is symmetric.
- What differs: the `--first-parent` chain. Merging upstream into a fork-based branch keeps our main's first-parent history "our work", with upstream as a side merge. Easier to answer "what's ours" later with `git log --first-parent`.
- If the current in-progress merge already went the other direction, finish it as-is. Standardize on next merge.

## Pre-flight

After `git merge upstream/develop` (or whatever ref), before touching anything:

```bash
# list conflicted files
git diff --name-only --diff-filter=U

# confirm direction — who is HEAD (ours) vs MERGE_HEAD (theirs)
cat .git/MERGE_HEAD
head -5 .git/MERGE_MSG
git log --oneline HEAD -3
git log --oneline MERGE_HEAD -3
```

Terminology used in this skill:
- **HEAD / current / ours** = the branch you're sitting on (the one receiving the merge).
- **MERGE_HEAD / incoming / theirs** = the branch being merged in.

If you're on a fork-based branch pulling upstream in: `HEAD` = fork, `MERGE_HEAD` = upstream.
If you're on an upstream-based branch pulling fork in (the less-preferred direction): `HEAD` = upstream, `MERGE_HEAD` = fork.

Read carefully which side is which before labeling decisions.

## Per-file decision framework

For each conflicted file, pick one of:

| Code | Meaning |
|------|---------|
| **KC** | Keep current (HEAD) — drop the incoming side |
| **AI** | Accept incoming (MERGE_HEAD) — drop the HEAD side |
| **CO** | Combination — merge both sides manually |
| **DEL** | Accept deletion — `git rm` (modify/delete conflict where one side deleted) |

Process:

1. Read the conflict markers to see what each side does.
2. `git log --oneline HEAD -5 -- <path>` and `git log --oneline MERGE_HEAD -5 -- <path>` — understand WHY each side changed it.
3. For modify/delete: `git ls-files -u <path>` shows which stages are present (1=base, 2=ours, 3=theirs).
4. For complex hunks: `git show HEAD:<path>` and `git show MERGE_HEAD:<path>` to see each full file.
5. Decide KC/AI/CO/DEL based on intent, not just diff.

## Recurring patterns in this repo

### Style/SaveBang noise

Our fork has `Rails/SaveBang: Enabled: true` in `.rubocop.yml`. Upstream doesn't enforce it as strictly. Consequence: when upstream touches any line near a persistence call, we see a conflict where our side says `save!`/`update!`/`destroy!`/`create!` and theirs says the non-bang version.

The cop flags more than just `save`. Full list it tries to add `!` to: `save`, `update`, `update_attributes`, `destroy`, `create`, `create_or_find_by`, `find_or_create_by`, `find_or_initialize_by`, `first_or_create`, `first_or_initialize`. Any of these can appear in a conflict.

- Most are **trivial** style churn from our fork's rubocop autofix, no semantic change.
- **Never blindly accept the bang rewrite (or run `rubocop -A`) without evaluating each offense individually.** The cop doesn't check the receiver's class — it matches by method name alone. Non-ActiveRecord receivers (POROs, service objects with their own `save`/`update`/`destroy` method, third-party libraries like Stripe, Kredis, OpenStruct wrappers, CSV/IO objects with `update`, filesystem objects with `destroy`) will raise `NoMethodError` at runtime. Caught by CI if there's a spec, silently broken in prod if not.
- For each SaveBang offense, read the surrounding code: what class is the receiver? If it's an ActiveRecord model, the autocorrect is safe. If it's anything else, either add the receiver to `.rubocop.yml`'s `Rails/SaveBang.AllowedReceivers` list (currently Stripe::Subscription, Stripe::Customer, Stripe::Invoice) or add a targeted `rubocop:disable Rails/SaveBang` comment.
- Safe workflow: run `bundle exec rubocop <files>` (without `-A`) first to see the offenses listed, evaluate each individually, then apply `-A` only once you've confirmed every receiver is an ActiveRecord object. Always review the diff before committing.

### Signature architecture (PR #79)

We deliberately removed upstream's editor-side signature manipulation (`addSignature`, `removeSignature`, `toggleSignatureInEditor`, signature-in-draft logic) and moved signature application to **send-time** (`getMessagePayload`). This prevents signature duplication, persistence in drafts, and position-toggle bugs.

When upstream adds or tweaks any signature-related code in:
- `app/javascript/dashboard/components/widgets/WootWriter/Editor.vue`
- `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`
- `app/javascript/dashboard/routes/dashboard/settings/profile/MessageSignature.vue`

→ Usually **AI (accept incoming = our fork)**, preserving the send-time architecture. Upstream's "fixes" may be rebuilding exactly what we tore out.

One exception worth porting as follow-up (NOT during merge): upstream's inline-image sanitization (`stripInlineBase64Images` + `INLINE_IMAGE_WARNING` i18n key) is orthogonal to architecture and would be a nice safety net in our send-time code.

### WhatsApp incoming message service

`app/services/whatsapp/incoming_message_base_service.rb` is the other frequent conflict zone. Our fork has two-layer locking (source_id lock + contact phone lock) plus a contact-level re-check for slow networks. Upstream evolves its simpler dedup logic.

Decision: **CO (combination)**. Keep the fork's `acquire_message_processing_lock` + `with_contact_lock` + explicit `clear_message_source_id_from_redis` in `ensure`. Layer upstream's improvements in (e.g., the `@contact.blocked? && !outgoing_echo` check) at the equivalent point inside the contact lock.

Adjacent file that may need follow-up: `app/services/whatsapp/incoming_message_service_helpers.rb` typically auto-merges to our version. That's correct. If upstream's `Whatsapp::MessageDedupLock` class becomes orphaned after a merge, `git rm` it (and its spec).

**Known regression hiding here:** `acquire_message_processing_lock` in our fork checks `@processed_params.try(:[], :messages).blank?`, which skips `:message_echoes` payloads. Echoes from WhatsApp Cloud native-app sends were being silently dropped. Fixed in the 4.13.0 merge by changing to `messages_data.blank?` and picking `:to` vs `:from` for the contact phone based on `outgoing_echo`. Keep that fix on future merges.

### db/schema.rb

Always conflicts because both sides have different migration versions. Resolution is mechanical but has traps:

1. Resolve the version-number conflict first so Ruby can parse the file (`ActiveRecord::Schema[7.1].define(version: ...)`). Pick the later timestamp.
2. Resolve every other Ruby conflict file (`installation_config.rb`, any model conflicts) so Rails can boot.
3. `bundle exec rails db:migrate` to apply pending migrations.
4. `bundle exec rails db:schema:dump` to regenerate.

**Traps to remember:**

- **Local dev DB may have tables from other branches** (kanban, features in progress). After `db:schema:dump`, diff against `git show HEAD:db/schema.rb` and `git show MERGE_HEAD:db/schema.rb` to find extras. Manually delete stray `create_table` blocks + any foreign-key references + column references in shared tables (`conversations.kanban_task_id`, etc.).

- **Custom SQL functions aren't dumpable.** `db:schema:dump` strips our `execute <<~SQL CREATE OR REPLACE FUNCTION f_unaccent(text)` block. Automated re-injection is wired via the `Rakefile` + `lib/tasks/internal_chat_search.rake` (`db:internal_chat:inject_schema_functions` runs as an `enhance` hook after `db:schema:dump`). If you see the block missing after a dump, the hook didn't run — check the Rakefile wiring and the task for a warning line like `Could not find insertion point ...`. The function itself is created by migration `20260410170003_add_unaccent_search_to_internal_chat.rb`.

- **Schema version may be stamped with a migration from another branch.** `db:schema:dump` uses `MAX(schema_migrations.version)`. If the dev DB has a kanban/other-branch migration with a higher timestamp, that version ends up in `schema.rb`. Manually set the version to the highest timestamp among migrations *present in this merge's `db/migrate/`*.

- **Quick integrity diff** (in Python — sed-free): parse HEAD's schema + MERGE_HEAD's schema + merged schema, compare column/index sets per table. Any table with columns outside HEAD∪MERGE_HEAD is a stray from another branch.

### annotate_rb vs auto_annotate_models

Upstream migrated `.annotaterb.yml` + `lib/tasks/annotate_rb.rake` and deleted the old custom `lib/tasks/auto_annotate_models.rake`. Our fork did a similar migration earlier with different config style.

- `.annotaterb.yml`: **KC** (upstream's format is more complete, symbol-key style).
- `lib/tasks/auto_annotate_models.rake`: **DEL** (`git rm`). Replacement is `lib/tasks/annotate_rb.rake` from upstream.

### InstallationConfig serialize

Upstream simplified to `serialize :serialized_value, coder: YAML, type: ActiveSupport::HashWithIndifferentAccess, default: {}.with_indifferent_access`. Our fork had a custom `SerializedValueCoder` handling both YAML strings and native jsonb hashes.

Test before choosing: create a legacy `InstallationConfig` where `serialized_value` is a YAML string inside the jsonb column, then confirm upstream's simpler version can still load it. If it works (it did in 4.13.0 merge with all 3 legacy formats: tagged YAML, symbol-key YAML, native hash), go **KC**. Otherwise keep the custom coder.

### i18n files

`config/locales/en.yml` / `pt_BR.yml` and `app/javascript/dashboard/i18n/locale/en/settings.json` / `pt_BR/settings.json` conflict because both sides add keys. Almost always **CO**: merge both key sets under the right parent.

When upstream only adds `en.yml` keys and not `pt_BR.yml`, match upstream's scope — do not invent pt_BR translations as part of the merge. Those come in as community PRs or a separate translation pass.

### New features from both sides

Controllers (`inboxes_controller`, `conversations_controller`), policies, routes, store modules, automation_rule action whitelist, spec describe-blocks — when both sides added net-new methods/endpoints/actions, the resolution is always **CO**. Keep both additions ordered sensibly.

## Validation flow

After staging all resolved files and before commit:

```bash
# parse sanity
ruby -c app/models/installation_config.rb
ruby -c db/schema.rb

# rails boots
bundle exec rails runner 'puts "ok"'

# migrations all apply
bundle exec rails db:migrate

# specs for each changed area at minimum
bundle exec rspec spec/models spec/policies
bundle exec rspec spec/services/whatsapp
bundle exec rspec spec/controllers/api/v1/accounts/inboxes_controller_spec.rb \
                  spec/controllers/api/v1/accounts/conversations_controller_spec.rb \
                  spec/controllers/api/v1/accounts/conversations/messages_controller_spec.rb

# targeted specs we touched
bundle exec rspec spec/services/action_service_spec.rb \
                  spec/services/automation_rules/action_service_spec.rb

# smoke: load real installation configs / other records touched by the merge
bundle exec rails runner 'InstallationConfig.find_each { |c| c.value }'
```

## Pre-commit pitfalls

1. **Husky rubocop check only inspects files with staged diff.** Upstream files merged as-is don't appear in the diff, so their offenses slip past the hook and blow up in CI. Before commit:
   ```bash
   bundle exec rubocop --parallel
   ```
   Run the full thing. Fix anything that comes up (most are `Rails/SaveBang` in upstream migrations/specs — safe to `rubocop -A` after receiver check).

2. **Frontend lint error vs warning.** `pnpm-lint-staged` eslint runs with `--max-warnings=0` in some configs; a warning appears as an error in the hook. Check the actual error line in the hook output, not the warning count.

3. **Missing imports after removing conflict hunks.** When resolving AI (accept incoming) conflicts in JS/Vue files, you can accidentally delete imports you still need. Example from 4.13.0: `replaceVariablesInMessage` in `ReplyBox.vue` — the `replaceText` method came in from main but its import was above the conflict. After keeping `replaceText`, add the import.

4. **Duplicate `defineExpose` / `setup()` returns.** Same category: when combining both sides of a Vue component, watch for duplicate `defineExpose({ ... })` calls or duplicate keys in the `setup()` return object. Consolidate.

## What this skill deliberately does NOT cover

- CI flakiness from shard redistribution (pre-existing test pollution involving `perform_enqueued_jobs` in `before_all`, test-prof `let_it_be`, and rspec-mocks interaction). Track separately.
- Frontend build pipeline issues unrelated to the merge.
- Upstream feature rollouts that need product decisions (e.g., adopting a new captain model in our UI).
