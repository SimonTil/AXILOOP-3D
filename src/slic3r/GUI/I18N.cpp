#include "I18N.hpp"

#include "libslic3r/libslic3r.h"

namespace Slic3r { namespace GUI {

wxString L_str(const std::string &str)
{
	//! Explicitly specify that the source string is already in UTF-8 encoding
	// AXILOOP-3D: replace the upstream app name like the other translate functions
	return I18N::rebrand(wxGetTranslation(wxString(str.c_str(), wxConvUTF8)));
}

// AXILOOP-3D: replacement of the upstream app name in translated texts
namespace I18N {

// Function to check whether a character glues the app name to a link, path or identifier.
// Returns true for ASCII letters and digits, '_', '/' and '\'.
static bool is_identifier_char(wxUniChar c)
{
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '/' || c == '\\';
}

// Function to replace the upstream app name ("OrcaSlicer", "Orca Slicer", ...) in a user-visible text by the app name.
// Returns the text, unchanged where the name is part of a link, domain or file name.
wxString rebrand(const wxString &text)
{
	// Skip the common case quickly
	if (text.Find("Orca") == wxNOT_FOUND)
		return text;

	// Name forms, including spellings used by translators (same list as axiloop/rebrand_translations.ps1)
	static const wxString names[] = { "OrcaSlicer", "Orca Slicer", "Orcaslicer", "Orca slicer", "Orca Dilimleyici" };
	const wxString app_name = wxString::FromUTF8(SLIC3R_APP_FULL_NAME);
	wxString out;
	out.reserve(text.length());

	size_t i = 0;
	while (i < text.length()) {
		size_t match_len = 0;
		for (const wxString &name : names)
			if (text.compare(i, name.length(), name) == 0) {
				match_len = name.length();
				break;
			}

		if (match_len > 0) {
			const size_t end = i + match_len;
			// Keep the name when it's glued to a link, path or identifier, e.g. "github.com/OrcaSlicer", "OrcaSlicer_logs"
			const bool glued_before = i > 0 && (is_identifier_char(text[i - 1]) || text[i - 1] == '.');
			const bool glued_after  = end < text.length() && is_identifier_char(text[end]);
			// Keep domains such as "orcaslicer.com" written with capitals
			const bool is_domain    = text.compare(end, 4, ".com") == 0 || text.compare(end, 4, ".org") == 0 || text.compare(end, 4, ".net") == 0;
			if (!glued_before && !glued_after && !is_domain) {
				out += app_name;
				i = end;
				continue;
			}
		}
		out += text[i];
		++i;
	}

	// Replace the short form "Orca" where it means the app itself (English source texts).
	// Names such as Orca Cloud, Orca Cube or Orca YOLO keep it (same list as axiloop/rebrand_translations.ps1).
	static const char *short_form_phrases[] = { "Orca will ", "Orca would ", "Orca can ", "Orca skips ", "printer and Orca.", "starting Orca." };
	for (const char *phrase : short_form_phrases) {
		wxString replacement(phrase);
		replacement.Replace("Orca", app_name);
		out.Replace(phrase, replacement);
	}
	return out;
}

} // namespace I18N

} }
