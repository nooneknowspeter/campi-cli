# Google Ads

This guide shows how to obtain the credentials `campi-cli` needs to read from
Google Ads, and how to set them in `.env`.

> [!NOTE]
>
> The Google Ads integration is read-only. `campi-cli platform google` fetches
> the account, the campaigns, the ad groups and the ads of an account, and
> renders them as a tree. Creating campaigns on Google Ads is not implemented
> yet; `apply` and `destroy` stop with `persistence is not implemented yet;
unable to write: google` before touching anything.

## Credentials

| Variable                             | Description                                                                  |
| ------------------------------------ | ---------------------------------------------------------------------------- |
| `CAMPI_GOOGLE_ADS_DEVELOPER_TOKEN`   | Google Ads developer token.                                                  |
| `CAMPI_GOOGLE_ADS_CLIENT_ID`         | OAuth client id of a Google Cloud project with the Google Ads API.           |
| `CAMPI_GOOGLE_ADS_CLIENT_SECRET`     | OAuth client secret of the same client.                                      |
| `CAMPI_GOOGLE_ADS_REFRESH_TOKEN`     | Refresh token of the Google Ads account user.                                |
| `CAMPI_GOOGLE_ADS_CUSTOMER_ID`       | Customer id of the account to read; hyphens are ignored.                     |
| `CAMPI_GOOGLE_ADS_LOGIN_CUSTOMER_ID` | Optional; manager account id used to reach a client account.                 |
| `CAMPI_GOOGLE_ADS_API_URL`           | Google Ads API base URL; defaults to `https://googleads.googleapis.com/v26`. |
| `CAMPI_GOOGLE_ADS_TOKEN_URL`         | OAuth token endpoint; defaults to `https://oauth2.googleapis.com/token`.     |

The tool exchanges the refresh token for a short-lived access token on every
run, so the refresh token is the only credential that has to be kept.

## Prerequisites

- A Google Ads account.
- Access to the Google Ads manager account.
- A Google Cloud project with the Google Ads API enabled.

## 1. Get a developer token

1. Open the [Google Ads manager account](https://ads.google.com/manageraccount)
   and make sure the account you want to read is linked to it.
2. Follow the Google Ads API [developer token](https://developers.google.com/google-ads/api/docs/access-token)
   instructions to request a token. New accounts get a test token that only
   works with test accounts.
3. Set `CAMPI_GOOGLE_ADS_DEVELOPER_TOKEN` to the token.

## 2. Create an OAuth client

1. Open the [Google Cloud console](https://console.cloud.google.com/), pick or
   create a project, and enable the **Google Ads API**.
2. Configure the OAuth consent screen and create an **OAuth client ID** of type
   _Web application_.
3. Set `CAMPI_GOOGLE_ADS_CLIENT_ID` and `CAMPI_GOOGLE_ADS_CLIENT_SECRET` to the
   client id and the client secret.

## 3. Get a refresh token

Authorize the client and exchange the returned access token for a refresh
token:

```sh
curl -sG "https://accounts.google.com/o/oauth2/auth" \
  --data-urlencode "client_id=<CLIENT_ID>" \
  --data-urlencode "scope=https://www.googleapis.com/auth/adwords" \
  --data-urlencode "redirect_uri=http://localhost" \
  --data-urlencode "response_type=code" \
  --data-urlencode "access_type=offline" \
  --data-urlencode "prompt=consent"
```

Paste the returned `code` to the token endpoint:

```sh
curl -sG "https://oauth2.googleapis.com/token" \
  --data-urlencode "client_id=<CLIENT_ID>" \
  --data-urlencode "client_secret=<CLIENT_SECRET>" \
  --data-urlencode "refresh_token=<CODE>" \
  --data-urlencode "grant_type=authorization_code" \
  --data-urlencode "redirect_uri=http://localhost"
```

The response contains the `refresh_token`. Set
`CAMPI_GOOGLE_ADS_REFRESH_TOKEN` to it. The refresh token is long lived; it is
revoked when the user revokes access or when the client is deleted.

## 4. Find the customer id

The customer id is the number shown in the Google Ads account, without
separators: `123-456-7890` becomes `1234567890`. The tool strips the hyphens
itself, so both forms work.

Set `CAMPI_GOOGLE_ADS_CUSTOMER_ID` to that value. When the account is reached
through a manager account, set `CAMPI_GOOGLE_ADS_LOGIN_CUSTOMER_ID` to the
manager account id as well.

## 5. Verify

```sh
cd <WORK_DIR>
campi-cli platform google
```

The command renders the account, the campaigns with their channel type and
status, and the ad groups and ads of every campaign:

```
Account: <account name> (<customer id>)
|- Campaigns
|  |- <campaign name> [<channel type>] <status>
|  |  |- <ad group name> [<status>]
|  |  |  |- <ad name> [<status>]
```

The statuses are the Google Ads ones: `ENABLED`, `PAUSED` and `REMOVED`. Ads
without a name are listed by their type, then by their id.

## Troubleshooting

| Symptom                                             | Cause                                            | Fix                                                            |
| --------------------------------------------------- | ------------------------------------------------ | -------------------------------------------------------------- |
| `could not exchange the google ads refresh token`   | The OAuth client or the refresh token is invalid | Check the client id, the client secret, and the refresh token. |
| `The OAuth client was not found` (`invalid_client`) | Wrong client id                                  | Use the id of the OAuth client that owns the refresh token.    |
| `401 Unauthorized`                                  | The access token or the developer token is wrong | Regenerate the refresh token and check the developer token.    |
| `403` with `developerTokenParameterError`           | The developer token is not valid for the account | Use a token issued for the manager account that owns it.       |
| `login-customer-id` errors                          | The account is a client account                  | Set `CAMPI_GOOGLE_ADS_LOGIN_CUSTOMER_ID` to the manager id.    |
| `Could not find customer`                           | The customer id is wrong                         | Use the numeric id without separators.                         |
