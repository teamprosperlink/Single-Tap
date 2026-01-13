# Enable Required APIs Manually

Firebase deployment के लिए कुछ APIs को enable करना पड़ता है। अगर automated deployment fail हो रहा है, तो manually enable कर दो।

## Steps:

### 1. Google Cloud Console खोलो
Go to: https://console.cloud.google.com/

### 2. Project Select करो
Top left में "dlink-f6cc9" select करो

### 3. APIs Enable करो

Search bar में जाओ और ये APIs enable करो:

#### **API 1: Cloud Build API**
- Search: `Cloud Build API`
- Click करो
- **ENABLE** button दबाओ
- Wait करो (1-2 min)

#### **API 2: Cloud Functions API**
- Search: `Cloud Functions API`
- Click करो
- **ENABLE** button दबाओ
- Wait करो

#### **API 3: Artifact Registry API**
- Search: `Artifact Registry API`
- Click करो
- **ENABLE** button दबाओ
- Wait करो

#### **API 4: Cloud Logging API** (Optional but recommended)
- Search: `Cloud Logging API`
- Click करो
- **ENABLE** button दबाओ

### 4. Wait करो
सभी APIs enable होने में **5-10 minutes** लग सकते हैं।

### 5. Deploy करो
जब सभी enable हो जाएं, तो run करो:

```bash
cd c:\Users\csp\Documents\plink-live
npx firebase deploy --only functions
```

## Alternative: Quick Deploy

अगर manually करना مुश्किल है, तो यह command try करो (यह आटोmactically enable करने की कोशिश करेगा):

```bash
npx firebase deploy --only functions --force
```

## If Still Failing:

1. Logout करो Firebase से:
```bash
npx firebase logout
```

2. फिर से login करो:
```bash
npx firebase login
```

3. Deploy करो:
```bash
npx firebase deploy --only functions
```

## Expected Output (Success):

```
✔ deploying functions
✔ functions[forceLogoutOtherDevices] Successful
✔ functions[onMessageCreated] Successful
✔ functions[onCallCreated] Successful
✔ functions[onInquiryCreated] Successful

✔ Deploy complete!
```
