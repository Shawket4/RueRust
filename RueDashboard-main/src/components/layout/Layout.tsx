import React, { useState } from "react";
import { Outlet } from "react-router-dom";
import { Sidebar } from "./Sidebar";
import { Header } from "./Header";
import { CommandPalette } from "./CommandPalette";

export default function Layout() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <div className="flex h-screen bg-background overflow-hidden">
      <Sidebar
        mobileOpen={mobileOpen}
        onMobileClose={() => setMobileOpen(false)}
      />

      <div className="flex-1 flex flex-col overflow-hidden min-w-0">
        <Header
          onMenuClick={() => setMobileOpen(true)}
          onSearchClick={() => {
            const event = new KeyboardEvent("keydown", {
              key: "k", metaKey: true, bubbles: true,
            });
            document.dispatchEvent(event);
          }}
        />

        <main
          className="flex-1 overflow-y-auto overflow-x-hidden"
          style={{ WebkitOverflowScrolling: "touch" }}
        >
          <Outlet />
        </main>
      </div>

      <CommandPalette />
    </div>
  );
}
