# transferec

### How the file transfer works

The mobile app generates self-signed certificate by itself and then serves HTTPS for other machines to upload to it or download from it.

### How to use curl to securely upload/download file

`curl` has a new option `--pinnedpubkey` that can check cert when connecting to server.

The mobile app shows cert SHA256 (in base64) on screen. So you can just use that.

But typing the hash can be so tiresome so you might prefer getting the hash on your client terminal and then compare them with your eyes to make sure you get the right hash.

One of the ways is using `openssl`. If the IP address of the mobile device is 192.168.0.100, then the following openssl command downloads the certificate and calculates SHA256 from it (in base64):

```
openssl s_client -connect 192.168.0.100:1111 2>&1 < /dev/null \
 | sed -n '/-----BEGIN/,/-----END/p' \
 | openssl x509 -noout -pubkey \
 | openssl pkey -pubin -outform der \
 | openssl dgst -sha256 -binary \
 | openssl enc -base64
```

Comparing the output on terminal with the cert hash shown on mobile app is necessary. If they are the same then MITM attack can be ruled out.

(Comparing hash with human eyes should be secure enough even if you skip/miss some characters https://security.stackexchange.com/questions/97377/secure-way-to-shorten-a-hash )

Now we can use `--pinnedpubkey` to do upload/download. The command below is the simplest form of example to get a successful response.

```
curl -v -k --pinnedpubkey 'sha256//PASTE_YOUR_CERT_HASH_HERE' https://192.168.0.100:1111
```

Use POST request with empty body for downloading file: `curl -v -k --pinnedpubkey 'sha256//PASTE_YOUR_CERT_HASH_HERE' -o example.pdf -X POST https://192.168.0.100:1111/example.pdf`

Use POST request with a body for uploading file: `curl -v -k --pinnedpubkey 'sha256//PASTE_YOUR_CERT_HASH_HERE' --data-binary "@example.pdf" -X POST https://192.168.0.100:1111/example.pdf`

(Note you need to add `x-sec` header with `curl` if you have set secret on your app: `-H 'x-sec: XXXXXXXXX'`)

### Alternatives to `openssl` for tentatively showing cert SHA256 (in base64)

POST request to `/` will get a JSON response containing cert hash ("ch")

```
curl -v -k -X POST https://192.168.0.100:1111
```

Like `openssl`, you still need to compare cert hash with human eyes to make sure they are the same! If they are the same then MITM attack can be ruled out.

---

And another possible way is to scan any FILE's QR code to get "ch" field (This also gets secret and ip). This way allows skipping the step of comparing hash with human eyes!

### How to prevent other people under the same Wi-Fi from downloading my files or uploading to my device?

1. Setting a secret can prevent other people from downloading/uploading.

2. If you just want to protect certain files, you could use some other software to encrypt your files.

### App-managed log

GET request will get you a response of the app internal log. It is just stored on device. Never uploaded to any server.

