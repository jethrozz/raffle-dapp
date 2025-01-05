import { useLayoutEffect, useRef } from 'react'
import { Box, Container, Flex, Heading } from "@radix-ui/themes";
import "./head.css";
import { gsap } from "gsap";


export function Head(){
    const head = useRef()
    useLayoutEffect(() => {
          // 添加 head_raffle hover 事件
          //
    const raffleTween = gsap.to(".head_raffle", {
      paused: true,
      x: 12,
      color: "#ff8c42",
      duration: 0.4
    });
    const capybaraTween = gsap.to(".head_capybara", {
      paused: true,
      y:0,
      color: "#901090",
      duration: 0.3
    });
      const headRaffle = document.querySelector(".head_logo");
      headRaffle?.addEventListener("mouseenter", () => {raffleTween.play(); capybaraTween.play()});
      headRaffle?.addEventListener("mouseleave", () => {raffleTween.reverse(); capybaraTween.reverse()});
    })

    return (<div ref={head} className="head_logo">
      <Heading className="head-text">0x
      </Heading>
      <Heading className='head_capybara'>Capybara</Heading>
      <Heading className="head_raffle"> Raffle</Heading>
    </div>)
}
