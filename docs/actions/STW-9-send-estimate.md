# Action for you: send the time estimate and submit date (STW-9) — DONE (2026-10-20)

**Who:** you (Claude cannot send this email for you).
**When:** before any build work starts, i.e. before STW-11 (scaffold) is merged.
**Jira:** https://stratyge.atlassian.net/browse/STW-9

## Why
Reverie3D tracks your progress against the estimate you give them. The ticket's acceptance criteria:
- Reply is sent before any build work starts and states an estimate of about 7 hours.
- Reply names one specific planned submit date.
- A copy of the message is kept in `docs/tickets/STW-9.md`.

## Steps
1. Pick a submit date you can commit to (one specific calendar date, not a range).
2. Reply to the Reverie3D trial email with the message below, filling in the date.
3. Paste the exact message you sent, with the date and time sent, into `docs/tickets/STW-9.md` under "Message sent". Don't include email addresses or phone numbers.
4. Tell Claude "STW-9 sent". Claude will commit the ticket doc, open the PR, and move STW-9 to Done in Jira with a comment.

## Message template
> Hi <name>,
>
> Thanks for the Stall Watch brief. My estimate is about 7 hours of focused work. I plan to submit by **<weekday, DD Month YYYY>**. I'll send the repository link, the deployed URL and the test credentials (as one-time secret links) on or before that date.
>
> Best regards,
> Jocarl Basco

## Done when
- [x] Email sent, with about 7 hours and one specific date (confirmed by the candidate)
- [x] Recorded in `docs/tickets/STW-9.md` (the message itself was private and is not reproduced)
- [x] You told Claude, and STW-9 is Done in Jira
