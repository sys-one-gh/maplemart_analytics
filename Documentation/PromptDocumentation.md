# Generative AI Usage — Prompt Documentation

**Platform**: Ollama, running the `mistral` model (7B, 4.4GB) locally in
Docker — no external API, no data leaves the machine. See
`Python/Ollama/client.py`, `Python/Ollama/prompts.py`,
`Python/Ollama/report_generator.py`.

All 5 required reports were generated in one run against the local database
(`Python/Ollama/report_generator.py:generate_all_reports()`), each stored via
`uspStoreAIReport` with `Approved = 0` pending the review below.
`PROMPT_VERSION = "v1.0"` for all 5 (no prompt revisions needed — first
attempt produced usable output for every report type).

---

## 1. Executive Summary

**Business question**: What's the overall health of the campaign analytics
program?

**Representative prompt actually sent** (data interpolated from
`_overall_metrics()` — a live query against `Customer`, `MarketingCampaign`,
`CampaignResponse`, `SalesTransaction`, `ModelExecution`):

```
You are a retail marketing analyst at MapleMart Canada, a 25-store grocery
retailer with the MapleRewards loyalty program.

Summarize the overall health of the customer campaign analytics program using this data:
- Total customers: 5000
- Active customers: 5000
- Total marketing campaigns: 40
- Overall campaign response rate: 44.0%
- Prediction model accuracy: 77.4%
- Total sales revenue: $28,092,739.84

Structure your response with exactly these five headed sections, in this
order: Executive Summary, Key Findings, Business Insights, Marketing
Recommendations, Conclusion. Base every claim strictly on the data given
below - do not invent numbers, customers, or campaigns that are not present
in the data. Keep the tone professional and concise (under 400 words total).
```

**Response summary**: Correctly used all 6 supplied figures with no invented
numbers. Followed the 5-section structure exactly. Recommended maintaining
campaign volume while pushing prediction accuracy above 80%.

**Modifications made**: None to the text of the final approved version, but
the *prompt* was revised. The first generation (v1.0) opened with "for Q1
2023" - a timeframe we never supplied; the model invented it rather than
omitting a period it wasn't given. Not a numeric fabrication (all 6
figures were correct), but a fabricated framing detail. Fixed in prompt
`v1.1` by adding an explicit instruction not to reference a time period
unless one is supplied. Regenerated under v1.1 and confirmed no timeframe
reference (or any other invented detail) in the new version.

**Verification performed**: Compared all 6 numbers in the response against
the live query result - all correct, in both v1.0 and v1.1 generations.
v1.1 output re-checked line by line for the same issue - confirmed absent.
**Approved.**

---

## 2. Campaign Analysis

**Business question**: Why did a specific campaign perform the way it did?

**Representative prompt** (data from `uspCampaignSummary`, campaign chosen
as the one with highest total revenue - Campaign 14):

```
You are a retail marketing analyst at MapleMart Canada.

Explain why the following campaign performed the way it did:
- Campaign: Campaign 14 (channel: SMS)
- Discount offered: 13.0%
- Customers contacted: [count from CampaignResponse]
- Open rate: 100.0%
- Purchase completion rate: 47.8%
- Total revenue generated: $30,260.71
- Average purchase amount: $134.49

[same 5-section structure instruction as above]
```

**Response summary**: Attributed the campaign's success to the SMS
channel's high open rate combined with an attractive discount, and
recommended testing different discount levels on SMS campaigns going
forward.

**Modifications made**: None.

**Verification performed**: All 6 supplied figures used correctly, no
invented ones. No fabricated time period this time (campaign-specific
prompts don't invite that the way the aggregate Executive Summary prompt
did). **Approved.**

---

## 3. Prediction Interpretation

**Business question**: What do the model's metrics mean, and is it reliable
enough to guide real spend?

**Representative prompt** (from `_latest_model_metrics()` — live query
against `ModelExecution` and `CustomerPrediction`):

```
You are a retail marketing analyst at MapleMart Canada explaining a machine
learning model's results to non-technical store managers.

Model: RandomForest
- Accuracy: 77.4%
- Precision: 71.6%
- Recall: 79.4%
- F1 Score: 75.3%
- Predicted positive responders: 2294 of 5000 customers

Explain in plain language what these numbers mean for targeting the next
campaign, and whether this model is reliable enough to guide real marketing
spend.

[same 5-section structure instruction]
```

**Response summary**: Correctly explained precision as "when the model
predicts a responder, it's right 71.6% of the time" and recall as "79.4% of
actual responders were caught" — an accurate plain-language translation,
not just restating the numbers. Concluded the model is "viable" but flagged
precision as the area with the most room for improvement.

**Modifications made**: None.

**Verification performed**: All 5 metrics and the 2294/5000 figure match
`ModelExecution`/`CustomerPrediction` exactly. Explanation of precision vs.
recall is technically correct, not just plausible-sounding. **Approved.**

---

## 4. Business Recommendations

**Business question**: What should the next quarter's campaigns do
differently?

**Representative prompt** (from `_best_campaign_and_channel()` +
`_latest_model_metrics()`):

```
You are a retail marketing analyst at MapleMart Canada preparing recommendations
for the next quarter's campaigns.

Data available:
- Best-performing channel: Mobile App
- Best-performing campaign: Campaign 18 (48.1% response rate)
- Model-predicted responders: 2294 customers
- Average discount on converting campaigns: 18.6%

Recommend concrete next steps for targeting, channel choice, and discount strategy.

[same 5-section structure instruction]
```

**Response summary**: Recommended increasing Mobile App investment and
using the predicted 2,294 responders as a targeting list, with a suggested
~18.6% discount ceiling to avoid margin erosion.

**Modifications made**: Same v1.0 → v1.1 prompt fix as report #1 (this
report also opened with "based on performance data from Q1" in the first
generation - same fabricated-timeframe pattern, same fix, same result:
regenerated clean).

**Verification performed**: All 4 supplied figures used correctly and
match source queries, in both generations. v1.1 output confirmed free of
invented timeframes. **Approved.**

---

## 5. Dashboard Commentary

**Business question**: What should a viewer notice first on the Executive
Overview dashboard?

**Representative prompt** (same `_overall_metrics()` data as report #1,
different framing/length constraint):

```
You are a retail marketing analyst at MapleMart Canada writing a short narrative
panel that will be displayed inside a Power BI dashboard, next to the charts described below.

Dashboard summary stats:
- Total customers: 5000
- Total revenue: $28,092,739.84
- Campaign response rate: 44.0%
- Prediction accuracy: 77.4%

Write a short narrative (under 150 words, still using the 5-section
structure) describing what a store manager viewing this dashboard should
notice first.

[same 5-section structure instruction]
```

**Response summary**: Opens with "Welcome to your MapleMart Canada
Dashboard!" — appropriately conversational for an in-dashboard text panel
rather than a formal report. Correctly used all 4 figures, no invented
timeframe this time.

**Modifications made**: None.

**Verification performed**: All figures match source data. Length and tone
appropriate for its intended placement (Dashboard 6 - Artificial
Intelligence). **Approved.**

---

## Summary

All 5 reports approved. 3 (Campaign Analysis, Prediction Interpretation,
Dashboard Commentary) were clean on the first generation. 2 (Executive
Summary, Business Recommendations) initially invented a "Q1" timeframe
that was never supplied, despite every actual number being correct in both
- caught during review, fixed by revising the prompt template to
explicitly forbid inventing a time period (`PROMPT_VERSION` `v1.0` →
`v1.1`, see `Python/Ollama/prompts.py`), and both regenerated and
re-verified clean before approval.

Zero instances of a wrong or invented *number* across all 5 reports, in
either prompt version - the issue found was narrative framing, not data
fabrication, but it's exactly why every report gets a human read before
`Approved = 1` rather than being auto-published on generation.
