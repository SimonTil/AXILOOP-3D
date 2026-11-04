# Code signing the Windows installer

This guide is for someone at Axiloop who doesn't program. It explains what a code-signing certificate does, what it takes to get one and how to sign the AXILOOP-3D installer. You don't need to change any program code for this.

Prices, rules and screens were checked against Microsoft's documentation in November 2026, and they can change. If a screen looks different, follow the Microsoft page listed under [Sources](#sources).

## In short

- Code signing puts Axiloop's verified name on the installer, so people can see who made it and that nobody changed it afterwards.
- **It doesn't remove the Windows warning straight away.** A new signed installer can still show a warning, but it names Axiloop as the publisher. The warning stops once enough people have installed the program, which can take several weeks and hundreds of installs.
- It's a yearly or monthly cost, and it takes from a few days to a few weeks to arrange, because Axiloop's identity has to be verified first.
- Start early, because the verification can't be rushed. Signing isn't required to release the program: without it, users can still choose "More info" and then "Run anyway".

## Choose a route

| | Route A: Microsoft Artifact Signing | Route B: certificate from a supplier |
|---|---|---|
| Cost | From about US$10 a month | About US$150 to US$500 a year |
| Who can use it | Companies in the USA, Canada, the EU, the UK, Australia, New Zealand, Japan, South Korea, Singapore, Switzerland, Norway and Israel | Companies worldwide |
| Company age | Microsoft asks for a verifiable tax history of at least 3 years | Set by the supplier |
| Extra hardware | None | A USB security key or the supplier's cloud service |
| Renewal | Automatic while the subscription is paid | Buy again at least every 460 days (about 15 months) |

**Choose Route A if Axiloop qualifies.** It's the cheapest option, and there's no security key to look after. Check two things first: the country where Axiloop is legally registered, and whether it has 3 years of tax history. If either one rules it out, use Route B.

Don't pay extra for an "EV" certificate to avoid the warning: Microsoft has confirmed that EV no longer skips it. A self-signed certificate is no use either, because Windows treats it the same as no signature.

## What you need for either route

- Axiloop's exact legal name, registered address and business registration number, as they appear in official records. Make sure those public records are up to date.
- Recent company documents, such as a business registration. They must be issued in the last 12 months, and if they have an expiry date, it must be at least 2 months away.
- A website and email addresses on a domain the company owns, such as `axiloop3d.com`. You may be asked for proof that the company owns the domain, such as a domain invoice.
- A person who represents the company, with a government ID and a smartphone, to confirm their identity.
- A company payment card.
- A Windows 10 or 11 PC to do the signing on.
- The finished, unsigned installer, for example `AXILOOP-3D_Windows_Installer_V0.1.0_x64.exe`. The person who builds the program provides this.

## Route A: Microsoft Artifact Signing

Parts 1 to 3 are done once. Part 4 is done for every release.

### Part 1: set up the account

1. Create a company account at [portal.azure.com](https://portal.azure.com) and add a subscription with the payment card.
2. Search for **Subscriptions**, open yours, and go to **Settings** → **Resource providers**. Select **Microsoft.CodeSigning**, then choose **Register**.
3. Search for **Artifact Signing Accounts** and choose **Create**:
   - **Resource group:** choose **Create new** and enter a name such as `axiloop-signing`.
   - **Account name:** a unique name such as `axiloopsigning`. Write it down.
   - **Region:** a nearby region, such as West Europe. Write it down.
   - **Pricing:** **Basic**, which includes 5,000 signatures a month and is far more than you need.
4. Select **Review + Create**, then **Go to resource**.
5. Give yourself two permissions, because the account owner doesn't get them automatically. In the new account, go to **Access Control (IAM)** → **Add** → **Add role assignment**, and add yourself to both of these roles:
   - **Artifact Signing Identity Verifier**
   - **Artifact Signing Certificate Profile Signer**

### Part 2: have Axiloop verified

1. In the account, open **Identity validations**. Select **Organization**, then **New Identity**, then **Public**.
2. Fill in the form carefully, because a mistake means starting a new request. The legal name you enter is what users will see as the publisher.
3. Use a primary email address on the company domain that is actually monitored, and a different secondary address on the same domain. Both must accept emails with links from outside the company. The links expire after 7 days.
4. Select **Create**. The status changes to **In Progress**.
5. When the status changes to **Action Required**, follow the link. The company's representative confirms their identity with their ID and phone, using the Microsoft Authenticator app.
6. Upload any further documents Microsoft asks for. There are only 3 upload attempts, so check each document against the list above first.
7. Wait for the email confirming that the status is **Completed**. This takes from 1 to 20 working days, and possibly longer if more documents are needed.

### Part 3: create the certificate profile and prepare the PC

1. In the account, open **Certificate profiles** → **Create** → **Public Trust**.
2. Enter a name such as `axiloop3d` and write it down. Under **Verified CN and O**, select your completed identity validation, then select **Create**.
3. On the signing PC, open **Windows PowerShell** and run these two commands, answering **Y** if you're asked to confirm:

   ```powershell
   winget install -e --id Microsoft.DotNet.Runtime.8
   Install-Module -Name ArtifactSigning -Scope CurrentUser
   ```

### Part 4: sign the installer (every release)

1. Open a new **Windows PowerShell** window.
2. Copy the text below into a text editor and replace the three example values and the file path:
   - **Endpoint:** the address for your region. West Europe is `https://weu.codesigning.azure.net`, North Europe is `https://neu.codesigning.azure.net` and East US is `https://eus.codesigning.azure.net`. Other regions are in Microsoft's [list of endpoints](https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations).
   - **CodeSigningAccountName:** the account name from part 1.
   - **CertificateProfileName:** the profile name from part 3.

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
   $params = @{
       Endpoint = "https://weu.codesigning.azure.net"
       CodeSigningAccountName = "axiloopsigning"
       CertificateProfileName = "axiloop3d"
       Files = "C:\Release\AXILOOP-3D_Windows_Installer_V0.1.0_x64.exe"
       FileDigest = "SHA256"
       TimestampRfc3161 = "http://timestamp.acs.microsoft.com"
       TimestampDigest = "SHA256"
   }
   Invoke-ArtifactSigning @params
   ```

3. Paste the edited text into PowerShell and press Enter. A browser window may open: sign in with the same Azure account.
4. Check the result. Right-click the installer and choose **Properties** → **Digital Signatures**. The list should show Axiloop's name and a timestamp.
5. Upload the signed installer to the release.

The timestamp line must stay in. Microsoft's certificates only last about 3 days, and the timestamp keeps the signature valid after that.

## Route B: certificate from a supplier

1. Buy an "OV code signing certificate" from a well-known supplier such as DigiCert, Sectigo or GlobalSign.
2. Choose the supplier's **cloud signing** if it's offered. The alternative is a USB security key, which is posted to you and has to be plugged in every time you sign. Secure keys are mandatory, so you'll never get an ordinary certificate file.
3. Supply the company details from [What you need](#what-you-need-for-either-route). Allow several working days for the supplier's checks.
4. Sign with the supplier's instructions, and make sure they include a **timestamp**. Without one, the signature stops being valid when the certificate expires.
5. Check the result as in step 4 of Route A.
6. Put the renewal date in the calendar. Renew with the same company name, so the reputation built up with Windows isn't affected.

## Every release: checklist

- Sign after the installer is finished. Changing the file afterwards breaks the signature.
- Check the **Digital Signatures** tab, then download the published file and run it once on a different PC.
- Don't publish an old checksum file. If the build created a `.sha256` file next to the installer, it no longer matches once the installer is signed.
- Always sign with the same company identity. Changing it affects the reputation built up with Windows.
- Tell new users that they may see a warning at first, that it should name Axiloop, and that they should only download from the official address.

## Keep access safe

Anyone who can sign can publish software in Axiloop's name.

- Give signing permission to as few people as possible, and protect those accounts with two-step sign-in.
- Never put passwords or keys in the GitHub repository, as it is public.
- If an account or security key may have been misused, contact Microsoft or the supplier immediately so that signing can be stopped.

## Common problems

| Problem | Solution |
|---|---|
| **New Identity** button is greyed out | Add the **Artifact Signing Identity Verifier** role to your account (part 1, step 5). |
| Error `403 Forbidden` while signing | The endpoint doesn't match the account's region, or you don't have the **Artifact Signing Certificate Profile Signer** role. |
| Error saying .NET 8 or `dotnet` is missing | Install it as in part 3, then open a new PowerShell window. |
| The verification email has expired or failed | Start a new identity validation request. |
| The warning still appears after signing | This is normal for a new publisher and fades as more people install the program. Check that it shows Axiloop's name. |

## For the developer

These tasks need someone who can change the build. They aren't set up or tested yet.

- **Sign the program itself.** The steps above sign only the installer, while the program files inside it stay unsigned. Microsoft advises signing all files, and Smart App Control on Windows 11 can block unsigned programs. These files must be signed before the installer is packed: `axiloop-3d.exe`, `OrcaSlicer.dll` and the other program files.
- **Automate signing.** Once the Windows build runs in GitHub Actions, Microsoft's [Artifact Signing action](https://github.com/azure/artifact-signing-action) can sign during the build. Keep the sign-in details in GitHub's encrypted secrets.
- **Consider the Microsoft Store.** It's the only route that avoids the warning entirely, because Microsoft signs Store apps itself. `scripts/msix/` contains the package setup, but it has not been built or tested; see "Open items" in `axiloop/CHANGED_FILES.md`.

## Sources

- [Code signing options for Windows app developers](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options)
- [SmartScreen reputation for Windows app developers](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)
- [Sign an MSIX package: eligibility for Artifact Signing](https://learn.microsoft.com/en-us/windows/msix/package/signing-package-overview)
- [Quickstart: Set up Artifact Signing](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart)
- [Assign roles in Artifact Signing](https://learn.microsoft.com/en-us/azure/artifact-signing/tutorial-assign-roles)
- [Set up signing integrations](https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations)
- [Artifact Signing pricing](https://azure.microsoft.com/en-us/pricing/details/artifact-signing/)
- [ArtifactSigning PowerShell module](https://www.powershellgallery.com/packages/ArtifactSigning/)
- [Code-signing certificate validity change (DigiCert)](https://www.digicert.com/blog/understanding-the-new-code-signing-certificate-validity-change)
