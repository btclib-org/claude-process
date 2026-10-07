<!-- markdownlint-disable-next-line first-line-heading -->
## What this changes

<!-- What the process says now that it did not say before, and why.
     Link the issue it closes, if there is one: "Closes #123". -->

## How it was verified

<!-- The command you ran and what it answered. The files here are text
     a session reads, so the measurement is the one each sentence of the
     change claims: the command that checks it. -->

## Checks

<!-- `lint.yml` is the whole of what a merge here can be gated on. The
     point of running it locally is not to wait for CI to say so. -->

- [ ] the lint gate is clean: `uvx pre-commit run --all-files`
- [ ] every commit carries a verified signature

## Anything the reviewer should know

<!-- A decision you are unsure of, an alternative you rejected, a
     follow-up you left out on purpose. Delete the section if there is
     none. -->
