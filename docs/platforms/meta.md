# Meta

This guide shows how to obtain the credentials `campi-cli` needs to read from
and write to Meta, and how to set them in `.env`.

## Credentials

| Variable                       | Description                                                         |
| ------------------------------ | ------------------------------------------------------------------- |
| `CAMPI_META_ACCESS_TOKEN`      | Long-lived Meta user access token with `ads_management`.            |
| `CAMPI_META_AD_ACCOUNT`        | Numeric ad account id; the tool prepends `act_`.                    |
| `CAMPI_META_PAGE_ID`           | Facebook Page id used as the ad creative destination.               |
| `CAMPI_META_INSTAGRAM_USER_ID` | Instagram user id used as the ad creative destination.              |
| `CAMPI_META_GRAPH_API_URL`     | Graph API base URL; defaults to `https://graph.facebook.com/v26.0`. |

At least one of `CAMPI_META_PAGE_ID` or `CAMPI_META_INSTAGRAM_USER_ID` is
required to create ad creatives. Leave the ones you do not use empty.

## Prerequisites

- A Meta business portfolio with an ad account.
- A Facebook Page.
- Optionally, an Instagram business or creator account linked to the Page.

## 1. Create and configure an app

1. Open the [Meta for Developers](https://developers.facebook.com/apps)
   dashboard and create an app of type **Business**.
2. Add the **Marketing API** product to the app.
3. In **App settings -> Basic**, note the **App ID** and **App secret**; they
   are needed to exchange a short-lived token for a long-lived one.

## 2. Grant the required permissions

When you generate the token, request at least:

- `ads_management`
- `ads_read`
- `business_management`
- `pages_show_list`
- `pages_read_engagement`
- `pages_manage_ads`
- `instagram_basic`

Add `leads_retrieval` if you plan to use the `LEADS` objective.

## 3. Switch the app to Live

Ad creatives are published as Page posts, and Meta rejects creative creation
from an app in **Development** mode:

```
Ads creative post was created by an app that is in development mode.
It must be in public to create this ad.
```

In the app dashboard, toggle **App mode** to **Live**. Until then, `apply -w`
creates the campaign, ad set, and ad image, then fails when it creates the ad
creative.

## 4. Create a long-lived user access token

1. Open the [Graph API Explorer](https://developers.facebook.com/tools/explorer/),
   select your app, add the permissions from step 2, and click
   **Generate Access Token**. This token is short lived (about an hour).
2. Extend it to a long-lived token (about 60 days) with the
   [Access Token Debugger](https://developers.facebook.com/tools/debug/accesstoken/)
   (**Extend Access Token**), or exchange it directly:

```sh
curl -sG "https://graph.facebook.com/v26.0/oauth/access_token" \
  --data-urlencode "grant_type=fb_exchange_token" \
  --data-urlencode "client_id=<APP_ID>" \
  --data-urlencode "client_secret=<APP_SECRET>" \
  --data-urlencode "fb_exchange_token=<SHORT_LIVED_TOKEN>"
```

Set `CAMPI_META_ACCESS_TOKEN` to the returned `access_token`.

## 5. Find the ad account id

```sh
curl -sG "https://graph.facebook.com/v26.0/me/adaccounts" \
  --data-urlencode "fields=name,account_id" \
  --data-urlencode "access_token=<TOKEN>"
```

Use the numeric `account_id` (without the `act_` prefix) as
`CAMPI_META_AD_ACCOUNT`.

## 6. Find the Page id

```sh
curl -sG "https://graph.facebook.com/v26.0/me/accounts" \
  --data-urlencode "fields=id,name" \
  --data-urlencode "access_token=<TOKEN>"
```

Use the returned page `id` as `CAMPI_META_PAGE_ID`.

## 7. Find the Instagram user id

1. Link an Instagram business or creator account to the Page, either from the
   Page **Settings -> Linked accounts** or from Meta Business Suite.
2. Query the Page for its linked Instagram account:

```sh
curl -sG "https://graph.facebook.com/v26.0/<PAGE_ID>" \
  --data-urlencode "fields=instagram_business_account" \
  --data-urlencode "access_token=<TOKEN>"
```

Set `CAMPI_META_INSTAGRAM_USER_ID` to the returned account `id`. This is the
Instagram **user** id, not the `ig_id` or the username.

`campi-cli platform meta` reads `/instagram_accounts`, which is scoped to the
Page and requires a Page access token. The tool derives the Page token from the
user token above, so `CAMPI_META_ACCESS_TOKEN` stays a user token.

## 8. Verify

```sh
cd <WORK_DIR>
campi-cli platform meta
```

The command renders the account, the pages the token can see, any Instagram
accounts linked to the configured page, and the campaign tree of ad sets and
ads:

```
Account: <name> (act_<id>)
|- Pages
|  |- <page name> [<page id>]
|- Instagram accounts
|  |- <name> (@<username>) id=<instagram user id>
|- Campaigns
|  |- <campaign name> [<objective>] <status>
|  |  |- <ad set name> [<status>]
|  |  |  |- <ad name> [<status>]
```

The pages come from `/me/accounts`, which requires `pages_show_list` (step 2).

## Token lifetime

- Short-lived user tokens expire in about an hour.
- Long-lived user tokens expire in about 60 days.
- Replace `CAMPI_META_ACCESS_TOKEN` with a fresh long-lived token before it
  expires, or scheduled `apply` runs fail with `code 190`.

Never commit `.env`. Revoke tokens you no longer use from the
[Access Token Debugger](https://developers.facebook.com/tools/debug/accesstoken/).

## Troubleshooting

| Symptom                                                                                   | Cause                                               | Fix                                                          |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------ |
| `Error validating access token ... Session has expired` (`code 190`)                      | Token expired                                       | Generate a new long-lived token.                             |
| `(#190) This method must be called with a Page Access Token`                              | A Page-scoped endpoint was called with a user token | Use `campi-cli platform meta`, which derives the Page token. |
| `Ads creative post was created by an app that is in development mode` (`subcode 1885183`) | App is in Development mode                          | Switch the app to Live (step 3).                             |
| Missing permission, or a scope error                                                      | Token lacks a permission                            | Add the scope and regenerate the token (step 2).             |
| Ad account not found                                                                      | The value includes the `act_` prefix or is wrong    | Use the numeric `account_id` only.                           |
