#include "HyperLink.hpp"
#include "Label.hpp"
#include "libslic3r/libslic3r.h"

namespace Slic3r { namespace GUI {

// AXILOOP-3D: links to the OrcaSlicer documentation say so in their label and tooltip

// Function to check whether a link opens the OrcaSlicer documentation.
// Returns true for orcaslicer.com links.
static bool is_orca_docs_link(const wxString& url) { return url.Contains("orcaslicer.com"); }

// Function to build the tooltip of a link.
// Returns the URL, preceded by a note for OrcaSlicer documentation links.
static wxString link_tooltip(const wxString& url)
{
    return is_orca_docs_link(url) ? wxString(SLIC3R_ORCA_DOCS_NOTE) + "\n" + url : url;
}

HyperLink::HyperLink(wxWindow* parent, const wxString& label, const wxString& url, long style)
    : wxStaticText(parent, wxID_ANY, is_orca_docs_link(url) ? label + " " SLIC3R_ORCA_DOCS_LABEL : label)
    , m_url(url)
    , m_normalColor(wxColour("#3B62AE")) // used slightly different color otherwise automatically uses ColorForDark that not visible enough
    , m_hoverColor(wxColour("#2C4F94"))
{
    SetForegroundColour(m_normalColor);
    HyperLink::SetFont(Label::Head_14);
    SetCursor(wxCursor(wxCURSOR_HAND));

    if (!m_url.IsEmpty())
        SetToolTip(link_tooltip(m_url));

    Bind(wxEVT_LEFT_DOWN, ([this](wxMouseEvent& e) {
             if (!m_url.IsEmpty())
                 wxLaunchDefaultBrowser(m_url);
         }));

    Bind(wxEVT_ENTER_WINDOW, ([this](wxMouseEvent& e) {
             SetForegroundColour(m_hoverColor);
             Refresh();
         }));
    Bind(wxEVT_LEAVE_WINDOW, ([this](wxMouseEvent& e) {
             SetForegroundColour(m_normalColor);
             Refresh();
         }));
}

bool HyperLink::SetFont(const wxFont& font)
{ // ensure it stays underlined
    wxFont f = font;
    f.SetUnderlined(true);
    return wxStaticText::SetFont(f);
}

void HyperLink::SetURL(const wxString& url)
{
    m_url = url;
    SetToolTip(link_tooltip(m_url));
    // Label a link that only now points to the OrcaSlicer documentation
    if (is_orca_docs_link(m_url) && !GetLabel().EndsWith(SLIC3R_ORCA_DOCS_LABEL))
        SetLabel(GetLabel() + " " SLIC3R_ORCA_DOCS_LABEL);
}

wxString HyperLink::GetURL() const { return m_url; }

}} // namespace Slic3r::GUI
