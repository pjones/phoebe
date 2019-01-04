# Rails user shell profile.

if [ -e "$HOME/.env" ]; then
  . "$HOME/.env"
fi

if [ -e "$HOME/../state/sourcedFile.sh" ]; then
  . "$HOME/../state/sourcedFile.sh"
fi
