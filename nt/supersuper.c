/**
 * @file   supersuper.c
 * @author Jussi Lahdenniemi <jussi@aprikoodi.fi>
 * @date   2011-09-30 23:54
 *
 * @brief  supersuper keyboard hook
 *
 * Hooks the keyboard, provides supersuper services to emacs.
 */

#define STRICT
#ifdef _WIN32_WINNT
# undef _WIN32_WINNT
#endif
#define _WIN32_WINNT 0x0500
#include <windows.h>
#include <stdio.h>

static HANDLE  h_quit;          /**< Event handle: quit the hook executable */
static HANDLE  h_lwin;          /**< Event handle: left Windows key pressed */
static HANDLE  h_rwin;          /**< Event handle: right Windows key pressed */

static int  lwindown  =  0;     /**< Left Windows key currently pressed */
static int  rwindown  =  0;     /**< Right Windows key currently pressed */
static int  capsdown  =  0;     /**< Caps lock currently pressed */
static int  winsdown  =  0;     /**< Number of handled keys currently pressed */
static int  suppress  =  0;     /**< Suppress Windows keyup for this press? */
static int  winseen   =  0;     /**< Windows keys seen during this press? */

/**
 * Determines whether an Emacs is currently on the foreground.
 *
 * @return nonzero if Emacs, zero if not.
 */
static int emacsp()
{
  HWND fg = GetForegroundWindow();
  if( fg != 0 )
    {
      TCHAR cls[16];
      GetClassName( fg, cls, 16 );
      return memcmp( cls, TEXT("Emacs"), sizeof(TEXT("Emacs"))) == 0;
    }
  return 0;
}

/**
 * The keyboard hook function.
 *
 * @param code Negative -> call next hook
 * @param w    Keyboard message ID
 * @param l    KBDLLHOOKSTRUCT'
 *
 * @return nonzero to terminate processing
 */
static LRESULT CALLBACK funhook( int code, WPARAM w, LPARAM l )
{
  KBDLLHOOKSTRUCT const* hs = (KBDLLHOOKSTRUCT*)l;
  if( code < 0 || (hs->flags & LLKHF_INJECTED))
    {
      return CallNextHookEx( 0, code, w, l );
    }

  if( hs->vkCode == VK_LWIN ||
      hs->vkCode == VK_RWIN ||
      hs->vkCode == VK_CAPITAL )
    {
      if( emacsp() && w == WM_KEYDOWN )
        {
          /* pressing key in emacs */
          if( hs->vkCode == VK_LWIN && !lwindown )
            {
              SetEvent( h_lwin );
              lwindown = 1;
              winseen = 1;
              winsdown++;
            }
          else if( hs->vkCode == VK_RWIN && !rwindown )
            {
              SetEvent( h_rwin );
              rwindown = 1;
              winseen = 1;
              winsdown++;
            }
          else if( hs->vkCode == VK_CAPITAL && !capsdown )
            {
              SetEvent( h_lwin );
              capsdown = 1;
              winsdown++;
            }
          return 1;
        }
      else if( winsdown > 0 && w == WM_KEYUP )
        {
          /* releasing captured key */
          if( hs->vkCode == VK_LWIN && lwindown )
            {
              lwindown = 0;
              winsdown--;
              if( !capsdown ) ResetEvent( h_lwin );
            }
          else if( hs->vkCode == VK_RWIN && rwindown )
            {
              rwindown = 0;
              winsdown--;
              ResetEvent( h_rwin );
            }
          else if( hs->vkCode == VK_CAPITAL && capsdown )
            {
              capsdown = 0;
              winsdown--;
              if( !lwindown ) ResetEvent( h_lwin );
            }
          if( winsdown == 0 && !suppress && winseen )
            {
              /* Releasing Win without other keys inbetween */
              INPUT inputs[2];
              memset( inputs, 0, sizeof(inputs));
              inputs[0].type = INPUT_KEYBOARD;
              inputs[0].ki.wVk = hs->vkCode;
              inputs[0].ki.wScan = hs->vkCode;
              inputs[0].ki.dwFlags = KEYEVENTF_EXTENDEDKEY;
              inputs[0].ki.time = 0;
              inputs[1].type = INPUT_KEYBOARD;
              inputs[1].ki.wVk = hs->vkCode;
              inputs[1].ki.wScan = hs->vkCode;
              inputs[1].ki.dwFlags = KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP;
              inputs[1].ki.time = 0;
              SendInput( 2, inputs, sizeof(INPUT));
            }
          if( winsdown == 0 )
            {
              suppress = 0;
              winseen = 0;
            }
          return 1;
        }
    }
  else if( winsdown > 0 )
    {
      /* S-? combination detected, do not pass keypress to Windows */
      suppress = 1;
    }
  return CallNextHookEx( 0, code, w, l );
}

/**
 * Main function for the application.
 *
 * @param inst        Instance handle
 * @param HINSTANCE   Not used
 * @param LPSTR       Not used
 * @param int         Not used
 *
 * @return Process exit code
 */
int CALLBACK WinMain( HINSTANCE inst, HINSTANCE prev, LPSTR args, int cmdshow )
{
  MSG msg;
  HHOOK hook;

  (void)prev; (void)args; (void)cmdshow;

  h_quit = CreateEvent( 0, TRUE, FALSE, "supersuper.quit" );
  if( GetLastError() == ERROR_ALREADY_EXISTS )
    {
      /* do not run twice */
      CloseHandle( h_quit );
      return 0;
    }
  h_lwin = CreateEvent( 0, TRUE, FALSE, "supersuper.left" );
  h_rwin = CreateEvent( 0, TRUE, FALSE, "supersuper.right" );
  hook = SetWindowsHookEx( WH_KEYBOARD_LL, funhook, inst, 0 );

  while( MsgWaitForMultipleObjects( 1, &h_quit, FALSE, INFINITE, QS_ALLINPUT ) != WAIT_OBJECT_0 )
    {
      while( PeekMessage( &msg, 0, 0, 0, PM_REMOVE ))
        {
          TranslateMessage( &msg );
          DispatchMessage( &msg );
        }
    }

  UnhookWindowsHookEx( hook );
  CloseHandle( h_lwin );
  CloseHandle( h_rwin );
  CloseHandle( h_quit );
  return 0;
}
