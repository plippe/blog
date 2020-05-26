Your source code is important. It defines everything about your application. How it runs. How it tests itself. How it gets deployed. A bad commit, at best, could take your application down, at worst, open access to your whole system. Why not monitor your repositories and avoid those issues?

Following the current trend of best practices, your repository should be popular. It should receive notifications for its tests, its test coverage, its code quality, its security, its add-ons, and I could go on. Services, providing these automated checks, use webhooks.

> *Webhooks allow external services to be notified when certain events happen. When the specified events happen, we’ll send a POST request to each of the URLs you provide.*
>
> *GitHub - webhooks settings page*

[GitLab](https://docs.gitlab.com/ee/user/project/integrations/webhooks.html#events) and [BitBucket](https://confluence.atlassian.com/bitbucket/event-payloads-740262817.html) have a long list of subscribable events, but only [GitHub](https://developer.github.com/webhooks/#events) has all the ones I am looking for:
- Member: Triggered when a user is added or removed as a collaborator to a repository or has their permissions changed.
- Membership: Triggered when a user is added or removed from a team.
- Organization: Triggered when a user is added, removed, or invited to an Organization.
- Org Block: Triggered when an organization blocks or unblocks a user.
- Public: Triggered when a private repository is open-sourced
- Team Add: Triggered when a repository is added to a team.

All these events are related to permissions. They are triggered when new, or existing users, gain access to repositories. Read rights shouldn’t be too much of an issue as all your secrets shouldn’t be hardcoded. On the other hand, write and admin permissions could be very damaging.

![Protect branch]({{ "/assets/images/posts/protect-branch.png" | absolute_url }})

This monitoring isn’t for a lack of trust in developers, but to catch compromised accounts or computers.

To add a new webhooks to GitHub open your organization’s, or repository’s setting page, head to the *Webhooks* section, and click on the *Add webhook* button. GitHub will request a URL, a content type for the payload, and a list of events.

Submitting a secret isn’t required, but greatly advised. The secret is used to sign requests. It allows differentiating those sent by GitHub from the others. You don’t want a random person just pinging your service.

```ruby
class GitHubController < ActionController::Base
  def webhook
    signature = request.headers['HTTP_X_HUB_SIGNATURE']
    body = request.body.read
    secret = ENV['SECRET']

    case verify_signature(signature, body, secret)
      when false then render :status => 401
      else
        ...
      end
  end

  def verify_signature(signature, body, secret)
    sha1 = OpenSSL::Digest.new('sha1')
    digest = OpenSSL::HMAC.hexdigest(sha1, secret, body)

    return Rack::Utils.secure_compare(signature, 'sha1=' + digest)
  end
end
```

Once the signature is validated, the body of the request can be used to take action. I would encourage you to log all requests to create a timeline. It might help identify the source of the issue and all affected repositories. Furthermore, notifying interested parties will help highlight unwanted chances.

Source code activity tracking doesn’t remove risks. It isn’t meant too. Similarly, logging won’t prevent your application from going down, but it helps diagnose the issues.
