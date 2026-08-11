# Data Dictionary

Generated from the actual deployed schema (`Database/Tables/*.sql`,
`Database/Constraints/05_CreateConstraints.sql`) - every type, nullability,
default, and constraint below matches what's really running, not a
separate design document that could drift from it.

## Reference tables

### Store
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| StoreID | Store identifier (from source data, not identity) | INT | N | Y | | | |
| StoreName | Display name | NVARCHAR(100) | N | | | | |
| City | Store city | NVARCHAR(100) | N | | | | |
| Province | Store province | NVARCHAR(50) | N | | | | |

### ProductCategory
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| CategoryID | Category identifier (from source data) | INT | N | Y | | | |
| CategoryName | Display name | NVARCHAR(100) | N | | | | |

### LoyaltyLevel
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| LoyaltyLevelID | Surrogate key | INT IDENTITY | N | Y | | auto-increment | |
| LevelName | e.g. Bronze/Silver/Gold/Platinum | NVARCHAR(50) | N | | | | UNIQUE |

### PaymentMethod
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| PaymentMethodID | Surrogate key | INT IDENTITY | N | Y | | auto-increment | |
| MethodName | e.g. Cash/Credit/Debit | NVARCHAR(50) | N | | | | UNIQUE |

### MarketingChannel
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| MarketingChannelID | Surrogate key | INT IDENTITY | N | Y | | auto-increment | |
| ChannelName | e.g. Email/SMS/Mobile App | NVARCHAR(50) | N | | | | UNIQUE |

### CampaignType
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| CampaignTypeID | Surrogate key | INT IDENTITY | N | Y | | auto-increment | |
| TypeName | Derived from DiscountPercent at load time (source has no type column) | NVARCHAR(50) | N | | | | UNIQUE |

## Operational tables

### Customer
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| CustomerID | Customer identifier (from source data) | INT | N | Y | | | |
| FirstName | | NVARCHAR(50) | N | | | | |
| LastName | | NVARCHAR(50) | N | | | | |
| Gender | | NVARCHAR(20) | Y | | | | |
| DateOfBirth | Authoritative source for Age (see Business Rules) | DATE | N | | | | |
| Age | Recomputed from DateOfBirth at load time, not trusted from source | INT | N | | | | CHECK: 18-120 |
| Email | | NVARCHAR(255) | Y | | | | Not unique - see DataQualityReport.md |
| Phone | | NVARCHAR(20) | Y | | | | |
| Address | | NVARCHAR(200) | Y | | | | |
| City | | NVARCHAR(100) | Y | | | | |
| Province | | NVARCHAR(50) | Y | | | | |
| PostalCode | | CHAR(7) | Y | | | | Format inconsistent in source, see DataQualityReport.md |
| RegistrationDate | | DATE | N | | | | |
| CustomerStatus | | NVARCHAR(20) | N | | | 'Active' | CHECK: Active/Inactive/Suspended |

### LoyaltyMembership
1:1 with Customer - keyed by `CustomerID` itself, not a separate surrogate,
to make a second membership per customer structurally impossible.

| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| CustomerID | | INT | N | Y | Customer | | |
| LoyaltyNumber | Business-facing membership number | NVARCHAR(20) | N | | | | UNIQUE |
| LoyaltyLevelID | | INT | N | | LoyaltyLevel | | |
| JoinDate | | DATE | N | | | | |
| CurrentPoints | | INT | N | | | 0 | CHECK: >= 0 |
| LifetimePointsEarned | | INT | N | | | 0 | CHECK: >= 0 |
| LifetimePointsRedeemed | | INT | N | | | 0 | CHECK: >= 0 |

### Employee
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| EmployeeID | | INT | N | Y | | | |
| FirstName | | NVARCHAR(50) | N | | | | |
| LastName | | NVARCHAR(50) | N | | | | |
| Role | | NVARCHAR(50) | N | | | | |
| StoreID | | INT | N | | Store | | |

### Product
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| ProductID | | INT | N | Y | | | |
| ProductName | | NVARCHAR(150) | N | | | | |
| CategoryID | | INT | N | | ProductCategory | | |
| Brand | | NVARCHAR(100) | Y | | | | |
| UnitPrice | | DECIMAL(10,2) | N | | | | CHECK: >= 0 |
| UnitCost | | DECIMAL(10,2) | N | | | | CHECK: >= 0 |

### MarketingCampaign
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| CampaignID | | INT | N | Y | | | |
| CampaignName | | NVARCHAR(150) | N | | | | |
| MarketingChannelID | | INT | N | | MarketingChannel | | |
| CampaignTypeID | Derived heuristically from DiscountPercent at load time | INT | Y | | CampaignType | | |
| StartDate | | DATE | N | | | | |
| EndDate | | DATE | N | | | | CHECK: >= StartDate |
| DiscountPercent | | DECIMAL(5,2) | N | | | | CHECK: 0-100 |

### SalesTransaction
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| TransactionID | | INT | N | Y | | | |
| CustomerID | | INT | N | | Customer | | |
| StoreID | | INT | N | | Store | | |
| TransactionDate | | DATETIME2 | N | | | | |
| PaymentMethodID | | INT | N | | PaymentMethod | | |
| TransactionTotal | Recomputed as SUM(line items) at load time - source column is 0 for every row, see DataQualityReport.md | DECIMAL(10,2) | N | | | | CHECK: >= 0 |

### SalesTransactionItem
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| TransactionItemID | | INT | N | Y | | | |
| TransactionID | | INT | N | | SalesTransaction | | |
| ProductID | | INT | N | | Product | | |
| Quantity | | INT | N | | | | CHECK: > 0 |
| UnitPrice | Price at time of sale - may differ from Product.UnitPrice today | DECIMAL(10,2) | N | | | | CHECK: >= 0 |
| Discount | Flat dollar amount, NOT a percent - see DataQualityReport.md | DECIMAL(10,2) | N | | | 0 | CHECK: >= 0 |
| LineTotal | = Quantity * UnitPrice - Discount | DECIMAL(10,2) | N | | | | CHECK: >= 0 |

### CampaignResponse
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| ResponseID | | INT | N | Y | | | |
| CampaignID | | INT | N | | MarketingCampaign | | |
| CustomerID | | INT | N | | Customer | | |
| EmailOpened | | BIT | N | | | 0 | |
| CouponUsed | | BIT | N | | | 0 | |
| PurchaseCompleted | ML target variable | BIT | N | | | 0 | |
| PurchaseAmount | | DECIMAL(10,2) | N | | | 0 | CHECK: >= 0 |
| ResponseDate | | DATETIME2 | N | | | | |

## Analytical tables (written by Python/Ollama pipeline, not loaded from CSV)

### CustomerPrediction
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| PredictionID | Surrogate key | INT IDENTITY | N | Y | | auto-increment | |
| CustomerID | | INT | N | | Customer | | |
| PredictionDate | | DATETIME2 | N | | | SYSDATETIME() | |
| PredictionProbability | | DECIMAL(5,4) | N | | | | CHECK: 0-1 |
| PredictionResult | | NVARCHAR(10) | N | | | | CHECK: Yes/No |
| MLModel | Algorithm name, e.g. "RandomForest" | NVARCHAR(50) | N | | | | |
| ModelVersion | | NVARCHAR(20) | N | | | | |

### AIReport
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| AIReportID | Surrogate key | INT IDENTITY | N | Y | | auto-increment | |
| ReportType | Executive Summary / Campaign Analysis / etc. | NVARCHAR(50) | N | | | | |
| CampaignID | Nullable - not every report is campaign-specific | INT | Y | | MarketingCampaign | | |
| GeneratedDate | | DATETIME2 | N | | | SYSDATETIME() | |
| ModelName | e.g. "mistral" | NVARCHAR(50) | N | | | | |
| PromptVersion | | NVARCHAR(20) | N | | | | |
| ReportText | | NVARCHAR(MAX) | N | | | | |
| Approved | Human review required before this flips to 1 | BIT | N | | | 0 | |

### ModelExecution
| Attribute | Purpose | Type | Nullable | PK | FK | Default | Business Rules |
|---|---|---|---|---|---|---|---|
| ExecutionID | Surrogate key | INT IDENTITY | N | Y | | auto-increment | |
| ExecutionDate | | DATETIME2 | N | | | SYSDATETIME() | |
| Algorithm | | NVARCHAR(50) | N | | | | |
| Accuracy | | DECIMAL(5,4) | N | | | | CHECK: 0-1 |
| Precision_ | Named with trailing underscore - PRECISION is a T-SQL reserved word | DECIMAL(5,4) | N | | | | CHECK: 0-1 |
| Recall | | DECIMAL(5,4) | N | | | | CHECK: 0-1 |
| F1Score | | DECIMAL(5,4) | N | | | | CHECK: 0-1 |
| ExecutionDurationSeconds | | DECIMAL(10,2) | N | | | | |
