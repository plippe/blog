Passwords make the life of your users difficult. Good ones are hard to remember, even harder to type, they should be unique and changed frequently. The only solution seems to be a password manager like [1password](https://1password.com/), or [lastpass](https://www.lastpass.com/), and a strict routine. It’s time to change this, let’s build something better.

User authentication is a simple process. A unique identifier is submitted to a server. In most cases, this is the user’s email and password. If it matches a known user, then a session is opened for that user. Extra steps can be added to the process, like two-factor authentication (2FA), but the idea is the same.

Instead of forcing a user to come up with a complex and unique identifier, the server can securely send it to them. This process is like the one often used to retrieve lost, or forgotten credentials.

A user starts the process by giving the server his contact details; e.g: email address, phone number. The server responds by sending an identifier to the user.

```ruby
@app.route('/users/login')
def login():
  contact_information = get_contact_information(request)

  if not valid_contact_information(contact_information):
    return Response(status=400)
  identifier = create_identifier()
  create_contact_information_identifier_combination(
    contact_information,
    identifier)
  send_identifier(contact_information, identifier)

  return Response(status=200)

def get_contact_information(request):
  """Returns the contact information found in the request"""

def valid_contact_information(contact_information):
  """Returns True if the contact information is valid"""

def create_identifier():
  """Returns an identifier complex enough not be guessed"""

def create_contact_information_identifier_combination(
  contact_information,
  identifier):
  """Save the contact information and identifier"""

def send_identifier(contact, identifier):
  """Send the identifier to the contact information"""
```

The user must submit this identifier to authenticate himself.

```ruby
@app.route('/users/verify')
def verify():
  contact_information = get_contact_information(request)
  identifier = get_identifier(request)

  combination = find_contact_information_identifier_combination(
    contact_information,
    identifier)

  if not combination:
    return Response(status=400)

  delete_contact_information_identifier_combination(combination)
  start_user_session(contact_information)

  return Response(status=200)

def get_identifier(request):
  """Returns the identifier found in the request"""

def find_contact_information_identifier_combination(
  contact_information,
  identifier):
  """Returns the saved contact information and identifier"""

def delete_contact_information_identifier_combination(
  contact_information_identifier):
  """Delete the saved contact information and identifier"""

def start_user_session(contact_information):
  """Start a session with the given contact information"""
```

The above solution solves all the issues highlighted at the start. Furthermore, it requires less work, than the typical approach, to put in place.

For your next projects, think of your users and say no to passwords.
