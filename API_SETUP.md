# 🔐 OpenAI API Key Setup

This Flutter coloring book app requires an OpenAI API key to generate coloring pages.

## 🚀 Quick Setup (2 minutes)

1. **Get your OpenAI API key**:
   - Visit [OpenAI Platform](https://platform.openai.com/api-keys)
   - Sign in or create an account
   - Click "Create new secret key"
   - Copy the key (starts with `sk-`)

2. **Create the .env file**:
   ```bash
   cp .env.example .env
   ```

3. **Add your API key to .env**:
   ```
   OPENAI_API_KEY=sk-your-actual-openai-api-key-here
   ```

4. **Run the app**:
   ```bash
   flutter pub get
   flutter run
   ```

## 🔒 Security Notes

- ✅ The `.env` file is automatically **git-ignored**
- ✅ Your API key **never gets committed** to version control
- ✅ Keep your API key **private and secure**
- ❌ **Never share** your API key with others

## 🚨 If You Get Errors

### "API key not configured" 
- Check that `.env` file exists in the project root
- Verify `OPENAI_API_KEY=` line has your actual key
- Make sure there are no extra spaces

### "Invalid API key"
- Ensure key starts with `sk-`
- Verify key is active on OpenAI platform
- Try creating a new key

## 💸 API Costs

- **DALL-E 3**: ~$0.040-0.120 per image generated
- **Tip**: Set spending limits on your OpenAI dashboard
- **Monitor**: Check usage at platform.openai.com

## 📁 File Structure
```
your-app/
├── .env                 # Your API key (git-ignored)
├── .env.example         # Template file (safe to commit)
└── lib/
    └── config/
        └── api_config.dart  # Loads your API key
```

---

**🎨 That's it! Your app is now ready to create magical coloring pages!**