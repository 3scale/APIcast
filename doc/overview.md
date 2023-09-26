# APIcast Overview

APIcast is an NGINX based API gateway used to integrate your internal and external API services with 3scale’s API Management Platform.

Here you’ll learn more about deployment options, environments provided, and how to get started.

## Deployment options

You can use APIcast hosted or self-managed, in both cases, it needs connection to the rest of the 3scale API management platform:
- **Embedded APIcast**: Two APIcast gateways (staging and production) come by default with the 3scale API Management installation. They come pre-configured and ready to use out-of-the-box.
- **Self-managed APIcast**: You can deploy APIcast wherever you want. Here are a few recommended options to deploy APIcast:
  - 'Local' deploy: Install dependencies (check out the [Tools and dependencies info](https://github.com/3scale/apicast#tools-and-dependencies) and get the any version of APIcast (or latest release published).
  - Docker: To avoid having to install APIcast dependencies, you can [download a ready to use dockerized image](https://github.com/3scale/apicast#docker) form our repository.
  - Running APIcast on Red Hat OpenShift: Run APIcast on a supported version of OpenShift. You can connect self-managed APIcasts to a 3scale On-premises installation or to a 3scale Hosted (SaaS) account.

## Environments

By default, when you create a 3scale account, you get APIcast **hosted** in two different environments:

- **Staging**: It's intended to be used only while configuring and testing your API integration. When you have confirmed that your setup is working as expected, then you can choose to deploy it to the production environment.
- **Production**: Limited 50,000 calls per day and supports the following out-of-the-box authentication options: App key, app key and app id pair.

## Getting API traffic in 1 minute

### Pre-requisites
- [Create a 3scale account](https://www.3scale.net/) (APIcast is not a standalone API gateway, it needs connection to 3scale's API Manager)
- Activate your 3scale account
- Log in to your 3scale Admin portal

Follow the next steps to configure your API gateway in no time:

### 1. Declare your API backend

Go to the **API** tab and select the default API, then click on **Integration**.

Add your API backend in the **private base URL**, which is the endpoint host of your API backend. For instance, if you were integrating with the Twitter API the Private Base URL would be ```https://api.twitter.com/```, or if you are the owner of the Sentiment API it would be ```http://api-sentiment.3scale.net/```.

The gateway will redirect all traffic to your API backend after all authentication, authorization, rate limits and statistics have been processed.

### Step 2: Update the hosted gateway

To update the **hosted gateway** you just have to **save** the settings (API backend, Advanced settings etc.) by clicking on the **Update & Test Staging Configuration** button in the lower right part of the page. This process will deploy your gateway configuration (at this stage the default configuration) to 3scale's hosted gateway.

### Step 3: Get a set of sample credentials

Go to the **Applications** tab, click on any application using the service you're configuring, and get the **API credentials**. If you do not have applications/users yet, you can create an application yourself (from the details page of any individual developer account), the credentials will be generated automatically.

Typically the credentials will be a ```user_key``` or the pair ```app_id/app_key``` depending on the authentication mode you are using (note that the 3scale hosted gateway does not currently support OAuth, however you can configure it if you are using the self-managed gateway integration).

### Step 4: Get a working request

We are almost ready to roll. Go to your browser (or command-line curl) and do a request to your own API to check that everything is working on your end.

For instance it could be something like this:

```
http://api-sentiment.3scale.net/v1/word/good.json
```
Note that you are not using 3scale's gateway yet. You are just getting a working example that will be used in the next step.

### Step 5: Get a working request to your API

Now do the same request but replacing your **private base URL** (in the example ```http://api-sentiment.3scale.net:80```) by your hosted endpoint (e.g. if you were integrating with the Twitter API, you would need to change the ```https://api.twitter.com``` to ```https://api-xxxxxxxxxxxxx.staging.apicast.io```). You also have to add the parameters to pass the credentials that you just copied.

Continuing the example in this tutorial it would be something like:

```
https://api-2445581436380.staging.apicast.io:443/v1/word/good.json?user_key=YOUR_USER_KEY
```

If you execute this request you will get the same result as in Step 4. However, this time the request will go through the 3scale hosted gateway.

**And that's it! You have your API integrated with 3scale**.

3scale's hosted gateway does the validation of the credentials and applies any gateway rules that you have defined to handle rate-limits, quotas and analytics. If you did not touch the mapping rules every request to the gateway will increase the metric ```hits``` by 1, you can check in your admin console how the metric ```hits``` is increased.

If you want to experiment further, you can test what happens if you try credentials that do not exist. The gateway will respond with a generic error message (you can define your custom one).

You can also define a rate limit of 1 request per minute. After you try your second request within the same minute you will see that the request never reaches your API backend. The gateway stops the request because it violates the quota that you have just set up.
