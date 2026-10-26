# The review bot's quota

Read this where a run of `Claude review` failed with its quota
exhausted, matched as `/btclib-pr`'s *Rebase and CI* says. This prints
the two lines of the log:

```shell
gh run view <run id> --repo <owner>/<repo> --log-failed |
  grep -E 'api_error_status 429|hit your .* limit'
```

The log gives the reset as `resets Oct 10, 11am (UTC)`, or as `resets
11am (UTC)` when it is less than a day away. Where it gives no date, the
reset is the first such hour after the log line's timestamp. Write it as
`2026-10-10T11:00`:

```shell
reset=<reset>
```

This prints `ahead` or `passed`:

```shell
expr "${reset:?}" \> "$(date -u +%Y-%m-%dT%H:%M)" > /dev/null &&
  echo ahead || echo passed
```

Where it prints `passed`, the session following the pull request
re-runs the failed run, and its result stands:

```shell
gh run rerun --repo <owner>/<repo> --failed <run id>
```

Where it prints `ahead`, a pull request whose only red check is this one
takes no reason label. `/btclib-pr`'s *The decision*, in its ACK item,
says what the missing ACK means.
