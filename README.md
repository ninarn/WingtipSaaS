# WingtipSaaS
A series of sample SaaS applications, each representing a common design pattern for SaaS applications built on SQL Database.

Each sample includes a series of management scripts and tutorials to help you jump start your own SaaS app project. These samples demonstrate a range of SaaS-focused designs and management patterns that can accelerate SaaS application development on SQL Database.

The same Wingtip Tickets application is implemented in each of the samples. The app is a simple event listing and ticketing SaaS app, where each venue is a tenant with events, ticket prices, customers, and ticket sales. The app, together with the management scripts and tutorials showcases an end-to-end SaaS scenario. This includes provisioning tenants, monitoring and managing performance, schema management and cross-tenant reporting and analytics, all at scale.

The three samples differ in the underlying database tenancy model used. The first uses a single-tenant application with an isolated single-tenant database. The second uses a multi-tenant app, still with a database per tenant. The third sample uses a multi-tenant app with sharded multi-tenant databases.

![Versions of Wingtip Tickets SaaS apps](./Documentation/AppVersions.PNG)

1. [Standalone application](https://github.com/Microsoft/WingtipTicketsSaaS-StandaloneApp)<br>
This sample uses a single tenant application with a single tenant database. Each tenant’s app is deployed into a separate Azure resource group. This could be in the service provider’s subscription or the tenant’s subscription and managed by the vendor on the tenant’s behalf. This pattern provides the greatest tenant isolation. But it is typically the most expensive as there is no opportunity to share resources across multiple tenants.

2. [Database-per-tenant](https://github.com/Microsoft/WingtipTicketsSaaS-DbPerTenant)<br>
The database per tenant model is effective for service providers that are concerned with tenant isolation and want to run a centralized service that allows cost-efficient use of shared resources. A database is created for each venue, or tenant, and all the databases are centrally managed. They can be hosted in elastic pools to provide cost-efficient and easy performance management, which leverages the unpredictable usage patterns of these small venues and their customers. A catalog database holds the mapping between tenants and their databases. This mapping is managed using the shard map management features of the Elastic Database Client Library, which also provides efficient connection management to the application.

3. [Hybrid sharded multi-tenant](https://github.com/Microsoft/WingtipTicketsSaaS-MultiTenantDb)<br>
Multi-tenant databases are effective for service providers looking for lower cost and simpler management and are fine with reduced tenant isolation. This model allows packing large numbers of tenants into a single database driving the cost down. This is preferred where only a small amount of data storage is required per tenant. Further flexibility is available in this model, allowing you to optimize for cost with multiple tenants in the same database, or optimize for isolation with a single tenant in a database. The choice can be made on a tenant-by-tenant basis, either when the tenant is provisioned or later, with no impact on the design of the application.

More information about the sample apps and the associated tutorials is here: [https://aka.ms/sqldbsaastutorial](https://aka.ms/sqldbsaastutorial)

Also available in the Documentation folder in this repo is an **overview presentation** that provides background, explores each SaaS app design model, and walks through several of the SaaS patterns at a high level. There is also a demo script you can use with the presentation to give others a guided tour of the app and several of the patterns.

## License
Microsoft Wingtip SaaS sample application and tutorials are licensed under the MIT license. See the [LICENSE](https://github.com/Microsoft/WingtipSaaS/blob/master/license) file for more details.

# Contributing
This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
