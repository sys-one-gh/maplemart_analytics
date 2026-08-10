"""Prompt TEMPLATES for the 5 required AI report types. Each function fills
in real data pulled from SQL Server via Database/repository.py - never
hand-write numbers into a prompt.

Every report must come back structured as:
  Executive Summary -> Key Findings -> Business Insights ->
  Marketing Recommendations -> Conclusion

PROMPT_VERSION bumps whenever the wording below changes materially -
Parth's Documentation/PromptDocumentation.md should reference the version
that produced each stored report.
"""

PROMPT_VERSION = "v1.0"

_STRUCTURE = (
    "Structure your response with exactly these five headed sections, in this order: "
    "Executive Summary, Key Findings, Business Insights, Marketing Recommendations, Conclusion. "
    "Base every claim strictly on the data given below - do not invent numbers, customers, or "
    "campaigns that are not present in the data. Keep the tone professional and concise "
    "(under 400 words total)."
)


def executive_summary_prompt(metrics: dict) -> str:
    return f"""You are a retail marketing analyst at MapleMart Canada, a 25-store grocery
retailer with the MapleRewards loyalty program.

Summarize the overall health of the customer campaign analytics program using this data:
- Total customers: {metrics['total_customers']}
- Active customers: {metrics['active_customers']}
- Total marketing campaigns: {metrics['total_campaigns']}
- Overall campaign response rate: {metrics['response_rate']:.1f}%
- Prediction model accuracy: {metrics['model_accuracy']:.1f}%
- Total sales revenue: ${metrics['total_revenue']:,.2f}

{_STRUCTURE}"""


def campaign_analysis_prompt(campaign: dict) -> str:
    return f"""You are a retail marketing analyst at MapleMart Canada.

Explain why the following campaign performed the way it did:
- Campaign: {campaign['CampaignName']} (channel: {campaign['ChannelName']})
- Discount offered: {campaign['DiscountPercent']}%
- Customers contacted: {campaign['CustomersContacted']}
- Open rate: {campaign['OpenRate']:.1f}%
- Purchase completion rate: {campaign['PurchaseCompletionRate']:.1f}%
- Total revenue generated: ${campaign['TotalRevenueGenerated']:,.2f}
- Average purchase amount: ${campaign['AveragePurchaseAmount']:,.2f}

{_STRUCTURE}"""


def prediction_interpretation_prompt(metrics: dict) -> str:
    return f"""You are a retail marketing analyst at MapleMart Canada explaining a machine
learning model's results to non-technical store managers.

Model: {metrics['algorithm']}
- Accuracy: {metrics['accuracy']*100:.1f}%
- Precision: {metrics['precision']*100:.1f}%
- Recall: {metrics['recall']*100:.1f}%
- F1 Score: {metrics['f1_score']*100:.1f}%
- Predicted positive responders: {metrics['predicted_positive_count']} of {metrics['total_scored']} customers

Explain in plain language what these numbers mean for targeting the next campaign, and
whether this model is reliable enough to guide real marketing spend.

{_STRUCTURE}"""


def business_recommendations_prompt(combined: dict) -> str:
    return f"""You are a retail marketing analyst at MapleMart Canada preparing recommendations
for the next quarter's campaigns.

Data available:
- Best-performing channel: {combined['best_channel']}
- Best-performing campaign: {combined['best_campaign']} ({combined['best_campaign_response_rate']:.1f}% response rate)
- Model-predicted responders: {combined['predicted_positive_count']} customers
- Average discount on converting campaigns: {combined['avg_discount_on_winners']:.1f}%

Recommend concrete next steps for targeting, channel choice, and discount strategy.

{_STRUCTURE}"""


def dashboard_commentary_prompt(metrics: dict) -> str:
    return f"""You are a retail marketing analyst at MapleMart Canada writing a short narrative
panel that will be displayed inside a Power BI dashboard, next to the charts described below.

Dashboard summary stats:
- Total customers: {metrics['total_customers']}
- Total revenue: ${metrics['total_revenue']:,.2f}
- Campaign response rate: {metrics['response_rate']:.1f}%
- Prediction accuracy: {metrics['model_accuracy']:.1f}%

Write a short narrative (under 150 words, still using the 5-section structure) describing
what a store manager viewing this dashboard should notice first.

{_STRUCTURE}"""
