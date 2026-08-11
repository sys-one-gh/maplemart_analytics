# Entity Relationship Diagram

Source of truth is `Database/Tables/*.sql` - this diagram is generated from
the actual deployed schema, not designed independently of it. Rendered with
Mermaid (renders natively on GitHub and most Markdow.

```mermaid
erDiagram
    Store ||--o{ Employee : "employs"
    Store ||--o{ SalesTransaction : "location of"
    ProductCategory ||--o{ Product : "categorizes"
    Product ||--o{ SalesTransactionItem : "sold as"
    LoyaltyLevel ||--o{ LoyaltyMembership : "tier of"
    PaymentMethod ||--o{ SalesTransaction : "paid via"
    MarketingChannel ||--o{ MarketingCampaign : "delivered via"
    CampaignType ||--o{ MarketingCampaign : "classified as"

    Customer ||--|| LoyaltyMembership : "has"
    Customer ||--o{ SalesTransaction : "makes"
    Customer ||--o{ CampaignResponse : "responds to"
    Customer ||--o{ CustomerPrediction : "scored by"

    SalesTransaction ||--o{ SalesTransactionItem : "contains"
    MarketingCampaign ||--o{ CampaignResponse : "generates"
    MarketingCampaign ||--o{ AIReport : "summarized by"

    Store {
        int StoreID PK
        nvarchar StoreName
        nvarchar City
        nvarchar Province
    }
    ProductCategory {
        int CategoryID PK
        nvarchar CategoryName
    }
    LoyaltyLevel {
        int LoyaltyLevelID PK
        nvarchar LevelName
    }
    PaymentMethod {
        int PaymentMethodID PK
        nvarchar MethodName
    }
    MarketingChannel {
        int MarketingChannelID PK
        nvarchar ChannelName
    }
    CampaignType {
        int CampaignTypeID PK
        nvarchar TypeName
    }
    Customer {
        int CustomerID PK
        nvarchar FirstName
        nvarchar LastName
        nvarchar Gender
        date DateOfBirth
        int Age
        nvarchar Email
        nvarchar Phone
        nvarchar Address
        nvarchar City
        nvarchar Province
        char PostalCode
        date RegistrationDate
        nvarchar CustomerStatus
    }
    LoyaltyMembership {
        int CustomerID PK_FK
        nvarchar LoyaltyNumber
        int LoyaltyLevelID FK
        date JoinDate
        int CurrentPoints
        int LifetimePointsEarned
        int LifetimePointsRedeemed
    }
    Employee {
        int EmployeeID PK
        nvarchar FirstName
        nvarchar LastName
        nvarchar Role
        int StoreID FK
    }
    Product {
        int ProductID PK
        nvarchar ProductName
        int CategoryID FK
        nvarchar Brand
        decimal UnitPrice
        decimal UnitCost
    }
    MarketingCampaign {
        int CampaignID PK
        nvarchar CampaignName
        int MarketingChannelID FK
        int CampaignTypeID FK
        date StartDate
        date EndDate
        decimal DiscountPercent
    }
    SalesTransaction {
        int TransactionID PK
        int CustomerID FK
        int StoreID FK
        datetime2 TransactionDate
        int PaymentMethodID FK
        decimal TransactionTotal
    }
    SalesTransactionItem {
        int TransactionItemID PK
        int TransactionID FK
        int ProductID FK
        int Quantity
        decimal UnitPrice
        decimal Discount
        decimal LineTotal
    }
    CampaignResponse {
        int ResponseID PK
        int CampaignID FK
        int CustomerID FK
        bit EmailOpened
        bit CouponUsed
        bit PurchaseCompleted
        decimal PurchaseAmount
        datetime2 ResponseDate
    }
    CustomerPrediction {
        int PredictionID PK
        int CustomerID FK
        datetime2 PredictionDate
        decimal PredictionProbability
        nvarchar PredictionResult
        nvarchar MLModel
        nvarchar ModelVersion
    }
    AIReport {
        int AIReportID PK
        nvarchar ReportType
        int CampaignID FK
        datetime2 GeneratedDate
        nvarchar ModelName
        nvarchar PromptVersion
        nvarchar ReportText
        bit Approved
    }
    ModelExecution {
        int ExecutionID PK
        datetime2 ExecutionDate
        nvarchar Algorithm
        decimal Accuracy
        decimal Precision_
        decimal Recall
        decimal F1Score
        decimal ExecutionDurationSeconds
    }
```

## 3NF Justification

**Reference tables** (`Store`, `ProductCategory`, `LoyaltyLevel`,
`PaymentMethod`, `MarketingChannel`, `CampaignType`): each holds a single
attribute (a name/description) keyed by a surrogate ID, eliminating the
repeating text values that would otherwise sit directly on every
`Customer`/`SalesTransaction`/`MarketingCampaign` row (e.g. without
`PaymentMethod`, the string `"Credit"` would repeat across ~25,000
transactions). No transitive dependencies possible with a single non-key
column.

**Operational tables**: every non-key column depends on the whole primary
key and nothing else. `LoyaltyMembership` is keyed by `CustomerID` (not a
separate surrogate) specifically because it's a true 1:1 with `Customer` -
using a different key would have allowed a data-integrity gap (a customer
with 2 memberships) that the schema is designed to make structurally
impossible. `SalesTransactionItem` carries its own `UnitPrice`/`Discount`
rather than deriving them from `Product` at query time, which looks like
denormalization but is correct here: it's a historical record of the price
*at the time of that sale*, which can legitimately differ from `Product`'s
current price - conflating the two would silently rewrite sales history
whenever `Product.UnitPrice` changes.

**Analytical tables** (`CustomerPrediction`, `AIReport`, `ModelExecution`):
each row is a complete, independent record of one model run / one
generated report - no partial dependencies, since the surrogate identity
key has no business meaning to depend on transitively.
